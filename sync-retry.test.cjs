const assert = require('node:assert/strict');
const fs = require('node:fs');
const test = require('node:test');
const vm = require('node:vm');

const source = fs.readFileSync('index.html', 'utf8');
const match = source.match(/function shouldRetryReportSync\(report\)\s*\{[\s\S]*?\n\}/);
const mergeMatch = source.match(/function mergeReportList\(cloudReports, localReports, deletedIds = getDeletedReportIds\(\)\)\s*\{[\s\S]*?\n\}/);
const reportIdMatch = source.match(/function createReportId\(prefix\)\s*\{[\s\S]*?\n\}/);
const syncErrorMatch = source.match(/function formatCloudSyncError\(context, error\)\s*\{[\s\S]*?\n\}/);
const retryDelayMatch = source.match(/function getReportSyncRetryDelay\(attempt\)\s*\{[\s\S]*?\n\}/);
const metadataMatch = source.match(/function prepareReportMetadataForCloud\(data\)\s*\{[\s\S]*?\n\}/);

test('retries only reports that are present locally and not deleted', () => {
  assert.ok(match, 'shouldRetryReportSync must exist');
  const context = { isReportDeleted: id => id === 'deleted' };
  vm.runInNewContext(`${match[0]}; this.shouldRetryReportSync = shouldRetryReportSync;`, context);

  assert.equal(context.shouldRetryReportSync({ id: 'pending' }), true);
  assert.equal(context.shouldRetryReportSync({ id: 'deleted' }), false);
  assert.equal(context.shouldRetryReportSync(null), false);
});

test('keeps cloud reports visible when this device has a local delete marker', () => {
  assert.ok(mergeMatch, 'mergeReportList must exist');
  const context = { getDeletedReportIds: () => new Set() };
  vm.runInNewContext(`${mergeMatch[0]}; this.mergeReportList = mergeReportList;`, context);

  const reports = context.mergeReportList(
    [{ id: 'cloud-report', reportNo: 'CLOUD' }],
    [{ id: 'cloud-report', reportNo: 'LOCAL' }, { id: 'deleted-draft', reportNo: 'DRAFT' }],
    new Set(['cloud-report', 'deleted-draft'])
  );

  assert.equal(reports.map(report => report.id).join(','), 'cloud-report');
  assert.equal(reports[0]._fromCloud, true);
});

test('creates a globally unique ID for a new report', () => {
  assert.ok(reportIdMatch, 'createReportId must exist');
  const context = { crypto: { randomUUID: () => 'new-report-id' } };
  vm.runInNewContext(`${reportIdMatch[0]}; this.createReportId = createReportId;`, context);

  assert.equal(context.createReportId('draft'), 'draft_new-report-id');
});

test('formats a safe, readable cloud sync error for the mobile UI', () => {
  assert.ok(syncErrorMatch, 'formatCloudSyncError must exist');
  const context = {};
  vm.runInNewContext(`${syncErrorMatch[0]}; this.formatCloudSyncError = formatCloudSyncError;`, context);

  assert.equal(
    context.formatCloudSyncError('Storage upload failed', new Error('new row violates row-level security policy')),
    'Storage upload failed: new row violates row-level security policy'
  );
});

test('retries a pending sync quickly before backing off', () => {
  assert.ok(retryDelayMatch, 'getReportSyncRetryDelay must exist');
  const context = { MAX_REPORT_SYNC_RETRY_MS: 30000 };
  vm.runInNewContext(`${retryDelayMatch[0]}; this.getReportSyncRetryDelay = getReportSyncRetryDelay;`, context);

  assert.equal(context.getReportSyncRetryDelay(0), 3000);
  assert.equal(context.getReportSyncRetryDelay(1), 6000);
  assert.equal(context.getReportSyncRetryDelay(4), 30000);
});

test('writes report metadata first and leaves new photos for background upload', () => {
  assert.ok(metadataMatch, 'prepareReportMetadataForCloud must exist');
  const storedPhoto = { fullPath: 'reports/id/photo.jpg', thumbPath: 'reports/id/photo-thumb.jpg' };
  const context = {
    STORAGE_BUCKET: 'wit-service-files',
    isStoragePhoto: photo => !!photo?.fullPath
  };
  vm.runInNewContext(`${metadataMatch[0]}; this.prepareReportMetadataForCloud = prepareReportMetadataForCloud;`, context);

  const cloudData = context.prepareReportMetadataForCloud({
    photos: [storedPhoto, 'data:image/jpeg;base64,new-photo'],
    photoThumbs: ['thumb'],
    reportNo: 'WIT-SR-001'
  });

  assert.equal(cloudData.photos.length, 1);
  assert.equal(cloudData.photos[0].fullPath, storedPhoto.fullPath);
  assert.equal(cloudData.photoStorage.pending, 1);
  assert.equal('photoThumbs' in cloudData, false);
});

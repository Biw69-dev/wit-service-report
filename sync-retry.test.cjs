const assert = require('node:assert/strict');
const fs = require('node:fs');
const test = require('node:test');
const vm = require('node:vm');

const source = fs.readFileSync('index.html', 'utf8');
const match = source.match(/function shouldRetryReportSync\(report\)\s*\{[\s\S]*?\n\}/);
const mergeMatch = source.match(/function mergeReportList\(cloudReports, localReports, deletedIds = getDeletedReportIds\(\)\)\s*\{[\s\S]*?\n\}/);
const reportIdMatch = source.match(/function createReportId\(prefix\)\s*\{[\s\S]*?\n\}/);

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

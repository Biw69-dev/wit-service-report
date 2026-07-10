const assert = require('node:assert/strict');
const fs = require('node:fs');
const test = require('node:test');
const vm = require('node:vm');

const source = fs.readFileSync('index.html', 'utf8');
const match = source.match(/function shouldRetryReportSync\(report\)\s*\{[\s\S]*?\n\}/);

test('retries only reports that are present locally and not deleted', () => {
  assert.ok(match, 'shouldRetryReportSync must exist');
  const context = { isReportDeleted: id => id === 'deleted' };
  vm.runInNewContext(`${match[0]}; this.shouldRetryReportSync = shouldRetryReportSync;`, context);

  assert.equal(context.shouldRetryReportSync({ id: 'pending' }), true);
  assert.equal(context.shouldRetryReportSync({ id: 'deleted' }), false);
  assert.equal(context.shouldRetryReportSync(null), false);
});

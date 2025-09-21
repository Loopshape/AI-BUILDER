const {deepStrictEqual} = require('node:assert').strict;
const test = require('node:test');
const {throws} = require('node:assert').strict;

const {featureFlagDetails} = require('./../');

const tests = [
  {
    args: {},
    description: 'A bit is required',
    error: 'ExpectedBitNumberToGetFeatureFlagDetails',
  },
  {
    args: {bit: 0},
    description: 'A feature flag is returned',
    expected: {type: 'data_loss_protection'},
  },
  {
    args: {bit: Number.MAX_SAFE_INTEGER},
    description: 'No feature flag is known',
    expected: {},
  },
];

tests.forEach(({args, description, error, expected}) => {
  return test(description, (t, end) => {
    if (!!error) {
      throws(() => featureFlagDetails(args), new Error(error), 'Got error');
    } else {
      const res = featureFlagDetails(args);

      deepStrictEqual(res.type, expected.type, 'Got expected type');
    }

    return end();
  });
});

const {deepStrictEqual} = require('node:assert').strict;
const test = require('node:test');
const {throws} = require('node:assert').strict;

const {featureFlagsFromWords} = require('./../');

const tests = [
  {
    args: {},
    description: 'An array of word numbers is required',
    error: 'ExpectedArrayOfWordNumbersToDeriveFeatureFlags',
  },
  {
    args: {words: [16, 0]},
    description: 'Feature flags are returned',
    expected: {features: [{bit: 9, is_required: false, type: 'tlv_onion'}]},
  },
];

tests.forEach(({args, description, error, expected}) => {
  return test(description, (t, end) => {
    if (!!error) {
      throws(() => featureFlagsFromWords(args), new Error(error), 'Got error');
    } else {
      const res = featureFlagsFromWords(args);

      deepStrictEqual(res.features, expected.features, 'Got feature bits');
    }

    return end();
  });
});

const {deepStrictEqual} = require('node:assert').strict;
const test = require('node:test');
const {throws} = require('node:assert').strict;

const {featureFlagsAsHex} = require('./../');

const tests = [
  {
    args: {},
    description: 'An array of features is required',
    error: 'ExpectedArrayOfFeaturesToEncodeAsHex',
  },
  {
    args: {features: []},
    description: 'Nil features is serialized',
    expected: {encoded: '0000'},
  },
  {
    args: {features: [0]},
    description: 'A feature flag is serialized',
    expected: {encoded: '000101'},
  },
];

tests.forEach(({args, description, error, expected}) => {
  return test(description, (t, end) => {
    if (!!error) {
      throws(() => featureFlagsAsHex(args), new Error(error), 'Got error');
    } else {
      const res = featureFlagsAsHex(args);

      deepStrictEqual(res.encoded, expected.encoded, 'Got serialization');
    }

    return end();
  });
});

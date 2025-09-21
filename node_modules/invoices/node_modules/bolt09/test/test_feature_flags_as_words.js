const {deepStrictEqual} = require('node:assert').strict;
const test = require('node:test');
const {throws} = require('node:assert').strict;

const {featureFlagsAsWords} = require('./../');

const tests = [
  {
    args: {},
    description: 'An array of features is required',
    error: 'ExpectedArrayOfFeatureBitsToEncodeAsWords',
  },
  {
    args: {features: []},
    description: 'Nil features is serialized',
    expected: {words: []},
  },
  {
    args: {features: [0]},
    description: 'A feature flag is encoded',
    expected: {words: [1]},
  },
];

tests.forEach(({args, description, error, expected}) => {
  return test(description, (t, end) => {
    if (!!error) {
      throws(() => featureFlagsAsWords(args), new Error(error), 'Got error');
    } else {
      const res = featureFlagsAsWords(args);

      deepStrictEqual(res.words, expected.words, 'Got words encoding');
    }

    return end();
  });
});

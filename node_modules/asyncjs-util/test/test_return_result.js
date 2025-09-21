const {deepStrictEqual} = require('node:assert').strict;
const {rejects} = require('node:assert').strict;
const test = require('node:test');
const {throws} = require('node:assert').strict;

const {returnResult} = require('./../');

const tests = [
  {
    args: {of: 'foo'},
    description: 'Return a specific result',
    error: null,
    expected: 'bar',
    result: {err: undefined, res: 'bar'},
  },
  {
    args: {},
    description: 'Return nothing',
    expected: undefined,
    result: {err: null, res: 'bar'},
  },
  {
    args: {},
    description: 'Failure',
    error: [500, 'Failure'],
    expected: undefined,
    result: {err: [500, 'Failure']},
  },
];

test('A callback or promise function is required', (t, end) => {
  throws(
    () => returnResult({}),
    new Error('ExpectedCbkOrPromiseFunctionsToReturnResult')
  );

  return end();
});

tests.forEach(({args, description, error, expected, result}) => {
  const promise = (err, resolution) => new Promise((resolve, reject) => {
    return returnResult({reject, resolve, of: args.of})(err, resolution);
  });

  return test(description, async () => {
    // Promise methods
    if (!error) {
      deepStrictEqual(await promise(null, {foo: result.res}), expected);
    } else {
      await rejects(promise(error), result.err);
    }

    // Callback methods
    return returnResult(args, (err, res) => {
      deepStrictEqual(err, error, 'Callback returns error');
      deepStrictEqual(res, expected, 'Callback returns result');

      return;
    })(result.err, {foo: result.res});
  });
});

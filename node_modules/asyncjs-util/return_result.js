/** Return a specific result of an async/auto process

  Omit a cbk and specify reject/resolve if using a Promise

  {
    [of]: <Property String>
    [reject]: <Promise Reject Function>
    [resolve]: <Promise Resolve Function>
  }
  [cbk]: <Callback Function>

  @returns
  <Function> (err, res) => {}
*/
module.exports = (args, cbk) => {
  if (!cbk && !(!!args.reject && !!args.resolve)) {
    throw new Error('ExpectedCbkOrPromiseFunctionsToReturnResult');
  }

  return (err, res) => {
    if (!!err) {
      return !cbk ? args.reject(err) : cbk(err);
    }

    if (!!args.of) {
      return !cbk ? args.resolve(res[args.of]) : cbk(null, res[args.of]);
    }

    return !cbk ? args.resolve() : cbk();
  };
};

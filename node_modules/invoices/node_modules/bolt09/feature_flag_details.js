const featureFlags = require('./feature_flags');

const isNumber = n => !isNaN(n);

/** Feature flag details for feature flag bit

  {
    bit: <Feature Flag Bit Number>
  }

  @throws
  <Error>

  @returns
  {
    [type]: <Feature Flag Type String>
  }
*/
module.exports = ({bit}) => {
  if (!isNumber(bit)) {
    throw new Error('ExpectedBitNumberToGetFeatureFlagDetails');
  }

  const flag = featureFlags[bit.toString()];

  return !flag ? {} : {type: flag.type};
};

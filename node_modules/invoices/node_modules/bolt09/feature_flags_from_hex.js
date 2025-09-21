const decodeFeatures = require('./decode_features');

const bits = 8;
const uint16ByteLength = 2;

/** Feature flags from hex serialized feature flags

  {
    [hex]: <Data Length Prefixed Hex Encoded String>
  }

  @throws
  <Error>

  @returns
  {
    features: [{
      bit: <Feature Bit Number>
      is_required: <Feature Bit is Required Bool>
      type: <Feature Bit Type String>
    }]
  }
*/
module.exports = ({hex}) => {
  if (!hex) {
    throw new Error('ExpectedHexSerializedFeatureFlagsToDecode');
  }

  const data = Buffer.from(hex, 'hex').slice(uint16ByteLength);
  const elements = [];

  for (const [_, currentByte] of data.entries()) {
    elements.push(currentByte);
  }

  return decodeFeatures({bits, elements});
};

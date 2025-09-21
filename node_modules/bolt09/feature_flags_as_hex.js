const encodeFeatures = require('./encode_features');

const {alloc} = Buffer;
const bits = 8;
const {concat} = Buffer;
const {isArray} = Array;
const uint16ByteLength = 2;

/** Encode feature flags into hex serialized bytes

  {
    features: [<Feature Bit Number>]
  }

  @throws
  <Error>

  @returns
  {
    encoded: <Serialized Feature Bits Hex Encoded String>
  }
*/
module.exports = ({features}) => {
  if (!isArray(features)) {
    throw new Error('ExpectedArrayOfFeaturesToEncodeAsHex');
  }

  const lengthBytes = alloc(uint16ByteLength);

  // Exit early with zero data length encoded when there are no features
  if (!features.length) {
    return {encoded: lengthBytes.toString('hex')};
  }

  const {data} = encodeFeatures({bits, features});

  lengthBytes.writeUInt16BE(data.length);

  return {encoded: concat([lengthBytes, data]).toString('hex')};
};

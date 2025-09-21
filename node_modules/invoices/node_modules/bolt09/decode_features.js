const featureFlagDetails = require('./feature_flag_details');

const isEven = number => !(number % 2);
const range = len => Array.from(Array(len).keys());

/** Decode feature flags

  {
    bits: <Bits Per Encoded Element Number>
    elements: [<Word Number or Data Byte>]
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
module.exports = ({bits, elements}) => {
  const endIndex = elements.length - 1;
  const features = new Set();

  elements.forEach((element, index) => {
    return range(bits)
      .filter(i => element & 1 << i)
      .forEach(i => features.add((endIndex - index) * bits + i))
  });

  return {
    features: Array.from(features).sort().map(bit => ({
      bit,
      is_required: isEven(bit),
      type: featureFlagDetails({bit}).type,
    })),
  };
};

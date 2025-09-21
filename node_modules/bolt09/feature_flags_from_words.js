const decodeFeatures = require('./decode_features');

const bits = 5;
const {isArray} = Array;

/** Feature flags from BOLT 11 tag words

  {
    words: [<BOLT11 Tag Word Number>]
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
module.exports = ({words}) => {
  if (!isArray(words)) {
    throw new Error('ExpectedArrayOfWordNumbersToDeriveFeatureFlags');
  }

  return decodeFeatures({bits, elements: words});
};

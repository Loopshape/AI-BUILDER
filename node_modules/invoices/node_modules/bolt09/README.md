# Bolt 09

[![npm version](https://badge.fury.io/js/bolt09.svg)](https://badge.fury.io/js/bolt09)
[![Coverage Status](https://coveralls.io/repos/github/alexbosworth/bolt09/badge.svg?branch=master)](https://coveralls.io/github/alexbosworth/bolt09?branch=master)
[![Build Status](https://travis-ci.org/alexbosworth/bolt09.svg?branch=master)](https://travis-ci.org/alexbosworth/bolt09)

Utility methods for working with [BOLT 09](https://github.com/lightningnetwork/lightning-rfc/blob/master/09-features.md)

## Methods

### featureFlagDetails

Feature flag details for feature flag bit

    {
      bit: <Feature Flag Bit Number>
    }

    @throws
    <Error>

    @returns
    {
      [type]: <Feature Flag Type String>
    }

Example:

```node
const {featureFlagDetails} = require('bolt09');

const {type} = featureFlagDetails({bit: 0});
// Type is string descriptor of feature bit
```

### featureFlagsAsHex

Encode feature flags into hex serialized bytes

    {
      features: [<Feature Bit Number>]
    }

    @throws
    <Error>

    @returns
    {
      encoded: <Serialized Feature Bits Hex Encoded String>
    }

Example:

```node
const {featureFlagsAsHex} = require('bolt09');

const {encoded} = featureFlagsAsHex({features: [0]});
// Encoded is hex encoded string with a length uint16 prefix
```

### featureFlagsAsWords

Encode feature flags into a serialized data buffer

    {
      features: [<Feature Bit Number>]
    }

    @throws
    <Error>

    @returns
    {
      words: [<Bech32 Word Number>]
    }

Example:

```node
const {featureFlagsAsWords} = require('bolt09');

const {words} = featureFlagsAsWords({features: [0]});
// Words are word numbers that can be used for encoding in a bolt11 payment req
```

### featureFlagsFromHex

Feature flags from hex serialized feature flags

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

Example:

```node
const {featureFlagsFromHex} = require('bolt09');

const {features} = featureFlagsFromHex({hex: '00018C'});
// Features is an array of supported features
```

### featureFlagsFromWords

Feature flags from BOLT 11 tag words

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

Example:

```node
const {featureFlagsFromWords} = require('bolt09');

const {features} = featureFlagsFromWords({words: [16, 0]});
// Features is an array of supported features
```

# Asyncjs Utilities

Utility methods for working with [asyncjs](http://caolan.github.io/async/v3/)

[![npm version](https://badge.fury.io/js/asyncjs-util.svg)](https://badge.fury.io/js/asyncjs-util)
[![Coverage Status](https://coveralls.io/repos/github/alexbosworth/asyncjs-util/badge.svg?branch=master)](https://coveralls.io/github/alexbosworth/asyncjs-util?branch=master)
[![Build Status](https://travis-ci.org/alexbosworth/asyncjs-util.svg?branch=master)](https://travis-ci.org/alexbosworth/asyncjs-util)

## getMaximum

Get maximum value through binary search

    {
      [accuracy]: <Close Enough Delta Number>
      from: <Minimum Number>
      to: <Maximum Number>
    }

    <Async Test Function> ({cursor}, (err, isLow) => {}) => {}

    @returns via cbk or Promise
    {
      maximum: <Maximum Number>
    }

## returnResult

Return a specific result of an async/auto process

Omit a cbk and specify reject/resolve if using a Promise

    {
      [of]: <Property String>
      [reject]: <Promise Reject Function>
      [resolve]: <Promise Resolve Function>
    }
    [cbk]: <Callback Function>

    @returns
    <Function> (err, res) => {}

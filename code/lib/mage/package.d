module mage;

// Standard
public import std.variant;
public import std.exception : enforce;
public import std.algorithm;
public import std.string;

// Externals
public import pathlib;

// Internals
public import log = mage.log;
public import mage.gen;
public import mage.target;
public import mage.config;

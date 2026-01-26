/* eslint-disable */
process.env.NODE_ENV ??= "development"

const { webpackConfig, merge } = require("@decidim/webpacker")
const customConfig = require("./custom")

const combinedConfig = merge(webpackConfig, customConfig)

module.exports = combinedConfig

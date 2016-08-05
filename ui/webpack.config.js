const webpack = require('webpack');
const path = require('path');

const baseLoader = {
  include: path.resolve(__dirname, "src"),
  test: /\.jsx?$/,
}

const eslintLoader = Object.assign({}, baseLoader, {
  loader: 'eslint-loader',
});
const babelLoader = Object.assign({}, baseLoader, {
  loader: 'babel',
  query: { presets: ['react', 'es2015'], plugins: ['transform-object-rest-spread'] },
  //TODO: source maps are currently broken in babel; also they leak absolute file paths
  // which should be fixed before re-enabling.
});

module.exports = {
  eslint: {
    configFile: 'eslint.config.js',
    failOnError: true,
  },
  module: {
    preLoaders: [ eslintLoader ],
    loaders: [ babelLoader ],
  },
  resolve: {
    extensions: ['','.js','.jsx']
  },
  entry: './src/App',
  output: {
    filename: 'app.js',
    path: 'build'
  },
  plugins: [
    new webpack.DefinePlugin({
      process: {
        env: {
          NODE_ENV: JSON.stringify(process.env.NODE_ENV || "development")
    }}})
  ],

};

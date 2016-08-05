var off = 0, warn = 1, err = 2;

module.exports = {
  plugins: ['react', 'import'],
  /*
  parserOptions: {
    ecmaFeatures: {
      jsx: true  //this seems to not work, but extending plugin:react/recommended below does set it.
    }
  },
  */
  parser: 'babel-eslint',
  env: {
    browser: true,
  },
  globals: {
    //defined by webpack; NODE_ENV=production disables debug
    "process": true,
  },
  extends: [
    'eslint:recommended',
    'plugin:react/recommended',
    'plugin:import/errors',
    'plugin:import/warnings',
  ],
  rules: {
    //TODO: create a stricter config for release builds?

    // not worth breaking the build over
    'no-unused-vars': warn,
    'comma-dangle': [warn, 'always-multiline'],
    'semi': [warn, 'always'],
    'quotes': [warn, 'single'],

    //legacy, to be fixed
    'react/display-name': warn,
    'react/prop-types': warn,

    // used during dev
    'no-console': warn,
    'no-debugger': warn,
  },
  settings: {
    'import/resolver': 'webpack',
  },
}

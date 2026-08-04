module.exports = {
  printWidth: 100,
  tabWidth: 2,
  useTabs: false,
  semi: true,
  singleQuote: true,
  trailingComma: 'es5',
  bracketSpacing: true,
  arrowParens: 'always',
  endOfLine: 'lf',
  plugins: ['prettier-plugin-organize-imports'],
  overrides: [
    {
      files: '*.{json,md,yml,yaml}',
      options: {
        printWidth: 120,
      },
    },
  ],
};
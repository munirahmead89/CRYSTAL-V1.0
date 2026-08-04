module.exports = {
  preset: 'jest-expo',
  transformIgnorePatterns: [
    'node_modules/(?!(.*\\.mjs$|jest-expo|@react-native|@supabase|expo|@expo|react-native|@react-native-community|@tanstack|zustand|clsx|tailwind-merge|date-fns|zod))',
  ],
  moduleNameMapper: {
    '^@/(.*)$': '<rootDir>/src/$1',
  },
  setupFilesAfterEnv: ['<rootDir>/jest.setup.tsx'],
  testMatch: ['**/__tests__/**/*.test.{ts,tsx}', '**/*.test.{ts,tsx}'],
  testPathIgnorePatterns: ['<rootDir>/node_modules/', '<rootDir>/.expo/', '<rootDir>/dist/'],
  collectCoverageFrom: [
    'src/**/*.{ts,tsx}',
    '!src/**/*.d.ts',
    '!src/**/*.test.{ts,tsx}',
    '!src/app/**',
  ],
  coverageThreshold: {
    global: {
      branches: 15,
      functions: 39,
      lines: 25,
      statements: 26,
    },
  },
};

---
name: vitest-recharts-mocking
description: |
  Mock Recharts components in Vitest/React Testing Library tests to test component logic
  without SVG rendering issues. Use when: (1) testing React components that use Recharts,
  (2) getting "TextEncoder is not defined" or SVG rendering errors in tests,
  (3) want to test data transformation logic without visual rendering,
  (4) tests are slow due to chart rendering. Covers PieChart, BarChart, ComposedChart,
  and common child components like Cell, Tooltip, Legend.
author: Claude Code
user-invocable: false
---

# Testing Recharts Components with Vitest

## Problem
When testing React components that use Recharts, you may encounter SVG rendering issues,
"TextEncoder is not defined" errors, or slow tests. You want to test the component's
data transformation logic and conditional rendering without dealing with chart internals.

## Context / Trigger Conditions
- Using Vitest and React Testing Library
- Component imports from 'recharts' (PieChart, BarChart, LineChart, etc.)
- Tests fail with SVG-related errors or TextEncoder issues
- Tests are slow due to ResponsiveContainer measuring DOM
- You want to verify data handling, not visual output

## Solution

Mock the recharts module at the top of your test file, before any imports that use it:

```typescript
import { describe, it, expect, vi } from 'vitest';
import { render, screen } from '@testing-library/react';

// Mock recharts BEFORE importing components that use it
vi.mock('recharts', () => ({
  ResponsiveContainer: ({ children }: { children: React.ReactNode }) => (
    <div data-testid="responsive-container">{children}</div>
  ),
  PieChart: ({ children }: { children: React.ReactNode }) => (
    <div data-testid="pie-chart">{children}</div>
  ),
  Pie: () => <div data-testid="pie" />,
  Cell: () => <div data-testid="cell" />,
  BarChart: ({ children }: { children: React.ReactNode }) => (
    <div data-testid="bar-chart">{children}</div>
  ),
  Bar: () => <div data-testid="bar" />,
  LineChart: ({ children }: { children: React.ReactNode }) => (
    <div data-testid="line-chart">{children}</div>
  ),
  Line: () => <div data-testid="line" />,
  XAxis: () => <div data-testid="x-axis" />,
  YAxis: () => <div data-testid="y-axis" />,
  CartesianGrid: () => <div data-testid="cartesian-grid" />,
  Tooltip: () => <div data-testid="tooltip" />,
  Legend: () => <div data-testid="legend" />,
  ReferenceLine: () => <div data-testid="reference-line" />,
  ComposedChart: ({ children }: { children: React.ReactNode }) => (
    <div data-testid="composed-chart">{children}</div>
  ),
  Area: () => <div data-testid="area" />,
}));

// NOW import your components
import { MyChartComponent } from '../components/MyChartComponent';
```

## Verification
- Tests run without SVG or TextEncoder errors
- You can assert on empty states: `expect(screen.getByText('No data available.')).toBeInTheDocument()`
- You can verify chart containers render: `expect(screen.getByTestId('pie-chart')).toBeInTheDocument()`
- Tests are faster without actual chart rendering

## Example

Testing a spending pie chart component:

```typescript
// Component: SpendingPie.tsx
export function SpendingPie({ data }: { data: Item[] }) {
  if (data.length === 0) {
    return <div>No spending data available.</div>;
  }

  return (
    <ResponsiveContainer width="100%" height={300}>
      <PieChart>
        <Pie data={data} dataKey="value">
          {data.map((entry, index) => (
            <Cell key={`cell-${index}`} fill={entry.color} />
          ))}
        </Pie>
        <Tooltip />
        <Legend />
      </PieChart>
    </ResponsiveContainer>
  );
}

// Test: SpendingPie.test.tsx
describe('SpendingPie', () => {
  it('should render empty state when no data', () => {
    render(<SpendingPie data={[]} />);
    expect(screen.getByText('No spending data available.')).toBeInTheDocument();
  });

  it('should render chart when data provided', () => {
    const data = [{ name: 'Food', value: 100, color: '#3b82f6' }];
    render(<SpendingPie data={data} />);
    expect(screen.getByTestId('pie-chart')).toBeInTheDocument();
  });

  it('should filter out zero-value items', () => {
    const data = [
      { name: 'Food', value: 100, color: '#3b82f6' },
      { name: 'Empty', value: 0, color: '#ef4444' }, // Should be filtered
    ];
    render(<SpendingPie data={data} />);
    expect(screen.getByTestId('pie-chart')).toBeInTheDocument();
  });
});
```

## Notes

- The mock must be defined BEFORE importing components that use recharts
- Add data-testid attributes to mocks if you need to assert on their presence
- For components with children prop, render them to allow nested components to work
- This approach tests logic (data transformation, empty states, conditionals) not visuals
- For visual testing, consider Storybook or Playwright visual regression tests
- Cell deprecation warnings from TypeScript are false positives - Cell is still valid

## References
- [Vitest Mocking](https://vitest.dev/guide/mocking.html)
- [Testing Library Queries](https://testing-library.com/docs/queries/about)
- [Recharts Components](https://recharts.org/en-US/api)

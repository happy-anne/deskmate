import type { Config } from 'tailwindcss'

/**
 * DeskMate design tokens — derived from the Toss (TDS) design system.
 * Blue #3182f6 is the sole interactive hue; warm-grey neutral scale;
 * single-layer neutral shadows; radii 8/12/16 + pill.
 */
export default <Partial<Config>>{
  content: [],
  theme: {
    extend: {
      colors: {
        primary: {
          DEFAULT: '#3182f6',
          hover: '#2272eb',
          50: '#e8f3ff',
          100: '#c9e2ff',
        },
        brand: '#0064ff',
        ink: '#191f28', // grey900 — headings
        grey: {
          50: '#f9fafb',
          100: '#f2f4f6',
          200: '#e5e8eb',
          300: '#d1d6db',
          400: '#b0b8c1',
          500: '#8b95a1',
          600: '#6b7684',
          700: '#4e5968',
          800: '#333d4b',
          900: '#191f28',
        },
        surface: '#f2f4f6',
        success: '#03b26c',
        error: '#f04452',
        warning: '#fe9800',
        teal: '#18a5a5',
      },
      fontFamily: {
        sans: [
          '"Toss Product Sans"',
          '"Pretendard Variable"',
          'Pretendard',
          '"SF Pro KR"',
          '-apple-system',
          'BlinkMacSystemFont',
          '"Apple SD Gothic Neo"',
          '"Noto Sans KR"',
          'sans-serif',
        ],
      },
      fontSize: {
        'display-hero': ['31px', { lineHeight: '41px', fontWeight: '700' }],
        'display-lg': ['27px', { lineHeight: '37px', fontWeight: '700' }],
        'heading-lg': ['23px', { lineHeight: '31px', fontWeight: '700' }],
        heading: ['21px', { lineHeight: '29px', fontWeight: '600' }],
        subtitle: ['17px', { lineHeight: '25px', fontWeight: '600' }],
        'body-lg': ['17px', { lineHeight: '25px', fontWeight: '400' }],
        body: ['15px', { lineHeight: '23px', fontWeight: '400' }],
        'body-sm': ['14px', { lineHeight: '21px', fontWeight: '400' }],
        caption: ['13px', { lineHeight: '19px', fontWeight: '400' }],
      },
      borderRadius: {
        sm: '4px',
        DEFAULT: '8px',
        md: '8px',
        lg: '12px',
        xl: '16px',
      },
      boxShadow: {
        subtle: '0px 1px 3px rgba(0,0,0,0.06)',
        header: '0px 1px 0 rgba(0,0,0,0.07)',
        card: '0px 2px 8px rgba(0,0,0,0.08)',
        elevated: '0px 4px 12px rgba(0,0,0,0.12)',
        modal: '0px 8px 24px rgba(0,0,0,0.16)',
        sheet: '0px -4px 12px rgba(0,0,0,0.08)',
      },
      spacing: {
        'safe-b': 'env(safe-area-inset-bottom)',
        'safe-t': 'env(safe-area-inset-top)',
      },
      maxWidth: { app: '700px' },
      transitionTimingFunction: {
        enter: 'cubic-bezier(0.0,0.0,0.2,1)',
        exit: 'cubic-bezier(0.4,0.0,1,1)',
        standard: 'cubic-bezier(0.4,0.0,0.2,1)',
        spring: 'cubic-bezier(0.34,1.56,0.64,1)',
      },
    },
  },
  plugins: [],
}

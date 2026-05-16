// @ts-check
import {themes as prismThemes} from 'prism-react-renderer';

/** @type {import('@docusaurus/types').Config} */
const config = {
  title: 'ShopStack Help',
  tagline: 'Documentation for your ShopStack system',
  favicon: 'img/favicon.png',

  future: {
    v4: true,
  },

  url: 'https://help.woodhead.tech',
  baseUrl: '/',

  onBrokenLinks: 'throw',

  i18n: {
    defaultLocale: 'en',
    locales: ['en'],
  },

  presets: [
    [
      'classic',
      /** @type {import('@docusaurus/preset-classic').Options} */
      ({
        docs: {
          sidebarPath: './sidebars.js',
          routeBasePath: '/',
        },
        blog: false,
        theme: {
          customCss: './src/css/custom.css',
        },
      }),
    ],
  ],

  themes: [
    [
      '@easyops-cn/docusaurus-search-local',
      /** @type {import('@easyops-cn/docusaurus-search-local').PluginOptions} */
      ({
        hashed: true,
        docsRouteBasePath: '/',
        indexBlog: false,
        language: 'en',
        highlightSearchTermsOnTargetPage: true,
        searchResultLimits: 8,
      }),
    ],
  ],

  themeConfig:
    /** @type {import('@docusaurus/preset-classic').ThemeConfig} */
    ({
      image: 'img/logo.png',
      colorMode: {
        defaultMode: 'light',
        respectPrefersColorScheme: true,
      },
      navbar: {
        title: 'ShopStack Help',
        logo: {
          alt: 'ShopStack by Woodhead Tech',
          src: 'img/logo.png',
        },
        items: [
          {
            type: 'docSidebar',
            sidebarId: 'help',
            position: 'left',
            label: 'Documentation',
          },
          {
            href: 'https://woodhead.tech/shopstack',
            label: 'ShopStack',
            position: 'right',
          },
          {
            href: 'mailto:brandon@woodhead.tech',
            label: 'Get Support',
            position: 'right',
          },
        ],
      },
      footer: {
        style: 'light',
        links: [
          {
            title: 'Documentation',
            items: [
              {label: 'Getting Started', to: '/'},
              {label: 'Email', to: '/email/'},
              {label: 'File Storage', to: '/files/'},
              {label: 'Invoicing', to: '/invoicing/'},
            ],
          },
          {
            title: 'Support',
            items: [
              {label: 'FAQ', to: '/faq'},
              {label: 'Contact Support', to: '/support'},
              {label: 'Email Brandon', href: 'mailto:brandon@woodhead.tech'},
            ],
          },
          {
            title: 'Woodhead Tech',
            items: [
              {label: 'Website', href: 'https://woodhead.tech'},
              {label: 'ShopStack', href: 'https://woodhead.tech/shopstack'},
              {label: 'Book a Call', href: 'https://cal.com/brandon-woodward-3nlfbd'},
            ],
          },
        ],
        copyright: `Copyright &copy; ${new Date().getFullYear()} Woodhead Tech`,
      },
      prism: {
        theme: prismThemes.github,
        darkTheme: prismThemes.dracula,
      },
    }),
};

export default config;

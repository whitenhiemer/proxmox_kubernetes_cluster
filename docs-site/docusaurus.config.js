// @ts-check
import {themes as prismThemes} from 'prism-react-renderer';

/** @type {import('@docusaurus/types').Config} */
const config = {
  title: 'woodhead.tech',
  tagline: 'Homelab infrastructure documentation',
  favicon: 'img/favicon.png',

  future: {
    v4: true,
  },

  url: 'https://docs.woodhead.tech',
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

  themeConfig:
    /** @type {import('@docusaurus/preset-classic').ThemeConfig} */
    ({
      image: 'img/logo.png',
      colorMode: {
        defaultMode: 'dark',
        respectPrefersColorScheme: true,
      },
      navbar: {
        title: 'woodhead.tech',
        logo: {
          alt: 'woodhead.tech',
          src: 'img/logo.png',
        },
        items: [
          {
            type: 'docSidebar',
            sidebarId: 'docs',
            position: 'left',
            label: 'Docs',
          },
        ],
      },
      footer: {
        style: 'dark',
        links: [
          {
            title: 'Documentation',
            items: [
              {label: 'Architecture', to: '/architecture'},
              {label: 'Runbook', to: '/runbook'},
              {label: 'Patching', to: '/patching'},
              {label: 'Roadmap', to: '/roadmap'},
            ],
          },
          {
            title: 'Services',
            items: [
              {label: 'Grafana', href: 'https://grafana.woodhead.tech'},
              {label: 'Home Assistant', href: 'https://home.woodhead.tech'},
              {label: 'Scanner', href: 'https://scanner.woodhead.tech'},
            ],
          },
        ],
        copyright: `Copyright &copy; ${new Date().getFullYear()} woodhead.tech`,
      },
      prism: {
        theme: prismThemes.github,
        darkTheme: prismThemes.dracula,
        additionalLanguages: ['bash', 'yaml', 'hcl', 'json', 'toml'],
      },
    }),
};

export default config;

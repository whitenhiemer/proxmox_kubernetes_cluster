/** @type {import('@docusaurus/plugin-content-docs').SidebarsConfig} */
const sidebars = {
  help: [
    'intro',
    {
      type: 'category',
      label: 'Email',
      link: {type: 'doc', id: 'email/index'},
      items: [
        'email/email-client-setup',
        'email/managing-mailboxes',
        'email/common-issues',
      ],
    },
    {
      type: 'category',
      label: 'File Storage',
      link: {type: 'doc', id: 'files/index'},
      items: [
        'files/desktop-sync',
        'files/mobile-sync',
        'files/sharing-files',
      ],
    },
    {
      type: 'category',
      label: 'Invoicing',
      link: {type: 'doc', id: 'invoicing/index'},
      items: [
        'invoicing/create-invoice',
        'invoicing/stripe-payments',
        'invoicing/recurring-invoices',
      ],
    },
    {
      type: 'category',
      label: 'Online Store',
      link: {type: 'doc', id: 'online-store/index'},
      items: [
        'online-store/products',
        'online-store/orders',
        'online-store/stripe-checkout',
      ],
    },
    'faq',
    'support',
  ],
};

export default sidebars;

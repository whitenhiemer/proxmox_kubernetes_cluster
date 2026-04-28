/** @type {import('@docusaurus/plugin-content-docs').SidebarsConfig} */
const sidebars = {
  docs: [
    'intro',
    {
      type: 'category',
      label: 'Infrastructure',
      items: ['architecture', 'roadmap'],
    },
    {
      type: 'category',
      label: 'Operations',
      items: ['runbook', 'patching'],
    },
    {
      type: 'category',
      label: 'Services',
      items: [
        'services/traefik',
        'services/monitoring',
        'services/arr-stack',
        'services/media',
        'services/sdr-scanner',
        'services/wireguard',
        'services/home-assistant',
        'services/authentik',
      ],
    },
    {
      type: 'category',
      label: 'Kubernetes',
      items: ['kubernetes/talos', 'kubernetes/workloads'],
    },
  ],
};

export default sidebars;

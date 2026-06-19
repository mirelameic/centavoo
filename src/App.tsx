import { useEffect, useState } from 'react';
import { Outlet, Link } from 'react-router-dom';
import {
  AppShell,
  Group,
  Text,
  Loader,
  Center,
  Stack,
  SegmentedControl,
  Menu,
  ActionIcon,
  FileButton,
} from '@mantine/core';
import { notifications } from '@mantine/notifications';
import { IconPlane, IconSettings, IconDownload, IconUpload } from '@tabler/icons-react';
import { ensureSeeded } from './db/seed';
import { exportBackup, importBackup } from './db/backup';
import { useI18n } from './i18n';

export function App() {
  const { t, lang, setLang } = useI18n();
  const [ready, setReady] = useState(false);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    ensureSeeded()
      .then(() => setReady(true))
      .catch((e) => setError(String(e)));
  }, []);

  async function handleExport() {
    await exportBackup();
    notifications.show({ message: t('backup.exportedOk'), color: 'teal' });
  }

  async function handleImport(file: File | null) {
    if (!file) return;
    try {
      await importBackup(file);
      notifications.show({ message: t('backup.importedOk'), color: 'teal' });
    } catch {
      notifications.show({ message: t('backup.importError'), color: 'red' });
    }
  }

  return (
    <AppShell header={{ height: 56 }} padding="md">
      <AppShell.Header>
        <Group h="100%" px="md" justify="space-between">
          <Group
            gap="xs"
            renderRoot={(props) => <Link to="/" {...props} />}
            style={{ textDecoration: 'none', color: 'inherit', cursor: 'pointer' }}
          >
            <IconPlane size={22} />
            <Text fw={700}>{t('app.title')}</Text>
          </Group>
          <Group gap="xs">
            <SegmentedControl
              size="xs"
              value={lang}
              onChange={(v) => setLang(v as 'pt' | 'en')}
              data={[
                { label: 'PT', value: 'pt' },
                { label: 'EN', value: 'en' },
              ]}
            />
            <Menu position="bottom-end" shadow="md" width={200}>
              <Menu.Target>
                <ActionIcon variant="subtle" color="gray" aria-label="menu">
                  <IconSettings size={20} />
                </ActionIcon>
              </Menu.Target>
              <Menu.Dropdown>
                <Menu.Item leftSection={<IconDownload size={16} />} onClick={handleExport}>
                  {t('menu.export')}
                </Menu.Item>
                <FileButton accept="application/json" onChange={handleImport}>
                  {(props) => (
                    <Menu.Item
                      closeMenuOnClick={false}
                      leftSection={<IconUpload size={16} />}
                      {...props}
                    >
                      {t('menu.import')}
                    </Menu.Item>
                  )}
                </FileButton>
              </Menu.Dropdown>
            </Menu>
          </Group>
        </Group>
      </AppShell.Header>

      <AppShell.Main>
        {error ? (
          <Center mih="60vh">
            <Stack align="center">
              <Text c="red">{t('error')}</Text>
              <Text size="sm" c="dimmed">{error}</Text>
            </Stack>
          </Center>
        ) : !ready ? (
          <Center mih="60vh">
            <Stack align="center">
              <Loader />
              <Text c="dimmed" size="sm">{t('loading')}</Text>
            </Stack>
          </Center>
        ) : (
          <Outlet />
        )}
      </AppShell.Main>
    </AppShell>
  );
}

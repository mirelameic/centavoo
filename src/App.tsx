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
} from '@mantine/core';
import { IconPlane } from '@tabler/icons-react';
import { ensureSeeded } from './db/seed';
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
          <SegmentedControl
            size="xs"
            value={lang}
            onChange={(v) => setLang(v as 'pt' | 'en')}
            data={[
              { label: 'PT', value: 'pt' },
              { label: 'EN', value: 'en' },
            ]}
          />
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

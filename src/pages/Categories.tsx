import { useState } from 'react';
import { Link, useParams } from 'react-router-dom';
import { useLiveQuery } from 'dexie-react-hooks';
import {
  Container,
  Title,
  Group,
  Stack,
  Text,
  Button,
  Card,
  ActionIcon,
  Modal,
  TextInput,
  ColorSwatch,
  SimpleGrid,
  UnstyledButton,
  Box,
  Anchor,
  Center,
} from '@mantine/core';
import { useDisclosure } from '@mantine/hooks';
import { IconPlus, IconPencil, IconTrash, IconArrowLeft, IconCheck } from '@tabler/icons-react';
import { db } from '../db/db';
import { addCategory, updateCategory, deleteCategory } from '../db/repo';
import type { Category } from '../db/schema';
import { COLOR_OPTIONS, EMOJI_OPTIONS } from '../lib/constants';
import { useI18n } from '../i18n';

const DEFAULT_COLOR = '#4263EB';

export function Categories() {
  const { t } = useI18n();
  const { id = '' } = useParams();
  const cats = useLiveQuery(
    () => db.categories.where('tripId').equals(id).sortBy('sortOrder'),
    [id],
  );

  const [opened, { open, close }] = useDisclosure(false);
  const [editing, setEditing] = useState<Category | null>(null);
  const openAdd = () => { setEditing(null); open(); };
  const openEdit = (c: Category) => { setEditing(c); open(); };

  async function handleDelete(c: Category) {
    if (window.confirm(t('cat.deleteConfirm'))) await deleteCategory(c.id);
  }

  return (
    <Container size="sm" px={0}>
      <Anchor component={Link} to={`/trip/${id}`} mb="sm" style={{ display: 'inline-flex', alignItems: 'center', gap: 4 }}>
        <IconArrowLeft size={16} /> {t('common.back')}
      </Anchor>
      <Group justify="space-between" mb="lg">
        <Title order={2}>{t('cat.title')}</Title>
        <Button leftSection={<IconPlus size={18} />} onClick={openAdd}>
          {t('cat.new')}
        </Button>
      </Group>

      {cats && cats.length === 0 && (
        <Center mih="30vh"><Text c="dimmed">{t('cat.empty')}</Text></Center>
      )}

      <Stack gap="xs">
        {cats?.map((c) => (
          <Card key={c.id} withBorder padding="sm">
            <Group justify="space-between">
              <Group gap="sm">
                <Box w={18} h={18} style={{ background: c.color, borderRadius: 4 }} />
                <Text>{c.icon ? `${c.icon} ` : ''}{c.name}</Text>
              </Group>
              <Group gap={2}>
                <ActionIcon variant="subtle" color="gray" onClick={() => openEdit(c)} aria-label="edit">
                  <IconPencil size={16} />
                </ActionIcon>
                <ActionIcon variant="subtle" color="red" onClick={() => handleDelete(c)} aria-label="delete">
                  <IconTrash size={16} />
                </ActionIcon>
              </Group>
            </Group>
          </Card>
        ))}
      </Stack>

      <CategoryModal opened={opened} onClose={close} tripId={id} editing={editing} />
    </Container>
  );
}

interface ModalProps {
  opened: boolean;
  onClose: () => void;
  tripId: string;
  editing: Category | null;
}

// The fields remount (via `key`) whenever the modal opens or the edited category
// changes, so state is initialized straight from props — no reset effect needed.
function CategoryModal({ opened, onClose, tripId, editing }: ModalProps) {
  const { t } = useI18n();
  return (
    <Modal opened={opened} onClose={onClose} title={editing ? t('common.edit') : t('cat.new')} centered>
      {opened && <Fields key={editing?.id ?? 'new'} tripId={tripId} editing={editing} onClose={onClose} />}
    </Modal>
  );
}

function Fields({ tripId, editing, onClose }: Omit<ModalProps, 'opened'>) {
  const { t } = useI18n();
  const [name, setName] = useState(editing?.name ?? '');
  const [color, setColor] = useState(editing?.color ?? DEFAULT_COLOR);
  const [icon, setIcon] = useState(editing?.icon ?? '');

  async function handleSave() {
    if (!name.trim()) return;
    const patch = { name: name.trim(), color, icon: icon.trim() || undefined };
    if (editing) await updateCategory(editing.id, patch);
    else await addCategory({ ...patch, tripId });
    onClose();
  }

  return (
    <Stack>
      <TextInput
        label={t('form.name')}
        value={name}
        onChange={(e) => setName(e.currentTarget.value)}
        data-autofocus
        required
      />
      <div>
        <Text size="sm" fw={500} mb={6}>{t('cat.color')}</Text>
        <Group gap="xs">
          {COLOR_OPTIONS.map((c) => (
            <ColorSwatch
              key={c}
              color={c}
              size={28}
              component="button"
              type="button"
              onClick={() => setColor(c)}
              style={{ cursor: 'pointer', color: '#fff' }}
            >
              {color === c && <IconCheck size={16} />}
            </ColorSwatch>
          ))}
        </Group>
      </div>
      <div>
        <Text size="sm" fw={500} mb={6}>{t('cat.emoji')}</Text>
        <SimpleGrid cols={8} spacing={6}>
          {EMOJI_OPTIONS.map((em) => (
            <UnstyledButton
              key={em}
              onClick={() => setIcon(icon === em ? '' : em)}
              style={{
                fontSize: 20,
                textAlign: 'center',
                padding: 4,
                borderRadius: 8,
                border:
                  icon === em
                    ? '2px solid var(--mantine-color-grape-5)'
                    : '1px solid var(--mantine-color-gray-3)',
                background: icon === em ? 'var(--mantine-color-grape-0)' : 'transparent',
              }}
            >
              {em}
            </UnstyledButton>
          ))}
        </SimpleGrid>
      </div>
      <Group justify="flex-end">
        <Button variant="default" onClick={onClose}>{t('common.cancel')}</Button>
        <Button onClick={handleSave} disabled={!name.trim()}>{t('common.save')}</Button>
      </Group>
    </Stack>
  );
}

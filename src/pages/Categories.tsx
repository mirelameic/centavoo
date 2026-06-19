import { useEffect, useState } from 'react';
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
  ColorInput,
  Box,
  Anchor,
  Center,
} from '@mantine/core';
import { useDisclosure } from '@mantine/hooks';
import { IconPlus, IconPencil, IconTrash, IconArrowLeft } from '@tabler/icons-react';
import { db } from '../db/db';
import { addCategory, updateCategory, deleteCategory } from '../db/repo';
import type { Category } from '../db/schema';
import { useI18n } from '../i18n';

const SWATCHES = [
  '#FF9900', '#9900FF', '#4A86E8', '#00B5C7', '#E6B800',
  '#FF0000', '#00C000', '#FF00FF', '#0CA678', '#4263EB',
];

export function Categories() {
  const { t } = useI18n();
  const { id = '' } = useParams();
  const cats = useLiveQuery(
    () => db.categories.where('tripId').equals(id).sortBy('sortOrder'),
    [id],
  );

  const [opened, { open, close }] = useDisclosure(false);
  const [editing, setEditing] = useState<Category | null>(null);
  const [name, setName] = useState('');
  const [color, setColor] = useState('#4263EB');
  const [icon, setIcon] = useState('');

  useEffect(() => {
    if (!opened) return;
    setName(editing?.name ?? '');
    setColor(editing?.color ?? '#4263EB');
    setIcon(editing?.icon ?? '');
  }, [opened, editing]);

  const openAdd = () => { setEditing(null); open(); };
  const openEdit = (c: Category) => { setEditing(c); open(); };

  async function handleSave() {
    if (!name.trim()) return;
    const patch = { name: name.trim(), color, icon: icon.trim() || undefined };
    if (editing) await updateCategory(editing.id, patch);
    else await addCategory({ ...patch, tripId: id });
    close();
  }

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

      <Modal opened={opened} onClose={close} title={editing ? t('common.edit') : t('cat.new')} centered>
        <Stack>
          <TextInput
            label={t('form.name')}
            value={name}
            onChange={(e) => setName(e.currentTarget.value)}
            data-autofocus
            required
          />
          <ColorInput
            label={t('cat.color')}
            format="hex"
            swatches={SWATCHES}
            value={color}
            onChange={setColor}
          />
          <TextInput
            label={t('cat.emoji')}
            placeholder="🏨"
            maxLength={4}
            value={icon}
            onChange={(e) => setIcon(e.currentTarget.value)}
          />
          <Group justify="flex-end">
            <Button variant="default" onClick={close}>{t('common.cancel')}</Button>
            <Button onClick={handleSave} disabled={!name.trim()}>{t('common.save')}</Button>
          </Group>
        </Stack>
      </Modal>
    </Container>
  );
}

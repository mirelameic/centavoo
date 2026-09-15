import { modals } from '@mantine/modals';
import { i18n } from '../i18n';

export function confirmDelete(message: string, onConfirm: () => void) {
  modals.openConfirmModal({
    withCloseButton: false,
    children: message,
    labels: { confirm: i18n.t('common.delete'), cancel: i18n.t('common.cancel') },
    confirmProps: { color: 'red' },
    centered: true,
    onConfirm,
  });
}

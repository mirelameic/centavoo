// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Centavoo';

  @override
  String get loading => 'Preparing your data…';

  @override
  String get error => 'Failed to load data.';

  @override
  String get tripsTitle => 'My trips';

  @override
  String get tripsNew => 'New trip';

  @override
  String get tripsEmpty => 'No trips yet.';

  @override
  String get tripsCreateFirst => 'Create the first one';

  @override
  String get tripsNetSpend => 'Net spend';

  @override
  String get tripsMoveUp => 'Move up';

  @override
  String get tripsMoveDown => 'Move down';

  @override
  String get formName => 'Name';

  @override
  String get formNamePlaceholder => 'e.g. Europe 2025';

  @override
  String get formDestination => 'Destination';

  @override
  String get formDestPlaceholder => 'e.g. Spain · Greece';

  @override
  String get formDates => 'Dates';

  @override
  String get formDatesPlaceholder => 'start – end';

  @override
  String get commonCancel => 'Cancel';

  @override
  String get commonDelete => 'Delete';

  @override
  String get commonCreate => 'Create';

  @override
  String get commonBack => 'Back';

  @override
  String get navTrips => 'Trips';

  @override
  String get kpiNet => 'Net';

  @override
  String get kpiGross => 'Gross';

  @override
  String get kpiRefunds => 'Refunds';

  @override
  String get kpiBefore => 'Before';

  @override
  String get kpiDuring => 'During';

  @override
  String get kpiAvgPerDay => 'Avg/day';

  @override
  String get tabSummary => 'Summary';

  @override
  String get tabTop => 'Ranking';

  @override
  String get tabTransactions => 'Transactions';

  @override
  String get chartBefore => 'Before';

  @override
  String get chartDuring => 'During';

  @override
  String get chartNoDated => 'No dated expenses in this period.';

  @override
  String get chartNoCity => 'No transactions with a city yet.';

  @override
  String get chartNoTop => 'No transactions yet.';

  @override
  String get cityPerDay => 'Cities per day';

  @override
  String get cityPlaceholder => 'city';

  @override
  String get cityList => 'Trip cities';

  @override
  String get cityAddCity => 'Add city';

  @override
  String get cityRemoveCity => 'Remove';

  @override
  String get cityBlockCityLabel => 'City';

  @override
  String get cityBlockRangeLabel => 'Date range';

  @override
  String get cityAddBlock => 'Add period';

  @override
  String get cityNoBlocks => 'No periods set yet.';

  @override
  String get cityDaysN => 'day(s)';

  @override
  String get cityUnassignedN => 'day(s) without a city';

  @override
  String get cityRemoveBlockConfirm =>
      'Remove this period? Those days will be left without a city.';

  @override
  String get cityRemoveUsedWarning =>
      'Removing it will also clear those days. Continue?';

  @override
  String get txDeleteSelected => 'Delete selected';

  @override
  String get txSelectedN => 'selected';

  @override
  String get txDeleteSelectedConfirm => 'Delete the selected transactions?';

  @override
  String get txSearchPlaceholder => 'Search description…';

  @override
  String get txFilterDate => 'Date';

  @override
  String get txFilterDatePlaceholder => 'any date';

  @override
  String get txDateModeDay => 'Day';

  @override
  String get txDateModeRange => 'Range';

  @override
  String get txFilterCategory => 'Category';

  @override
  String get txFilterCategoryPlaceholder => 'all categories';

  @override
  String get txFilterCity => 'City';

  @override
  String get txFilterCityPlaceholder => 'all cities';

  @override
  String get txFilterPeriod => 'Period';

  @override
  String get txPeriodAll => 'All';

  @override
  String get txFilterResultsN => 'result(s)';

  @override
  String get txClearFilters => 'Clear filters';

  @override
  String get txSelect => 'Select';

  @override
  String get txCancelSelect => 'Cancel';

  @override
  String get txSelectAll => 'Select all';

  @override
  String get txClearSelection => 'Clear selection';

  @override
  String get txDeleteOne => 'Delete';

  @override
  String get txSortBy => 'Sort by';

  @override
  String get txSortDefault => 'Default';

  @override
  String get tableDate => 'Date';

  @override
  String get tableDescription => 'Description';

  @override
  String get tableCategory => 'Category';

  @override
  String get tableCity => 'City';

  @override
  String get tablePeriod => 'Period';

  @override
  String get tableAmount => 'Amount';

  @override
  String get tableFull => 'full';

  @override
  String get periodBefore => 'Before';

  @override
  String get periodDuring => 'During';

  @override
  String get tripNotFound => 'Trip not found.';

  @override
  String get commonSave => 'Save';

  @override
  String get commonEdit => 'Edit';

  @override
  String get txNew => 'New transaction';

  @override
  String get txEdit => 'Edit transaction';

  @override
  String get txDeleteConfirm => 'Delete this transaction?';

  @override
  String get fieldType => 'Type';

  @override
  String get fieldSplit => 'Split by';

  @override
  String get typeExpense => 'Expense';

  @override
  String get typeRefund => 'Refund';

  @override
  String get typeIof => 'IOF refund';

  @override
  String get menuCategories => 'Categories';

  @override
  String get menuExport => 'Export data';

  @override
  String get menuImport => 'Import data';

  @override
  String get catTitle => 'Categories';

  @override
  String get catNew => 'New category';

  @override
  String get catColor => 'Color';

  @override
  String get catIcon => 'Icon';

  @override
  String get catEmpty => 'No categories.';

  @override
  String get catDeleteConfirm =>
      'Delete category? Its transactions will be left uncategorized.';

  @override
  String get backupExportedOk => 'Backup exported.';

  @override
  String get backupImportedOk => 'Backup imported successfully.';

  @override
  String get backupImportError => 'Invalid backup file.';

  @override
  String get backupExportError => 'Could not export the backup.';

  @override
  String get tabTime => 'Time';

  @override
  String get tabCities => 'Cities';

  @override
  String get tabCats => 'Categories';

  @override
  String get secCumulative => 'Cumulative spend';

  @override
  String get secByDay => 'By day';

  @override
  String get secWeekday => 'By weekday';

  @override
  String get secByCity => 'By city';

  @override
  String get secCityTable => 'City summary';

  @override
  String get secCatTable => 'Category summary';

  @override
  String get secBeforeDuring => 'Before × During';

  @override
  String get secTopBefore => 'Top spends · before';

  @override
  String get secTopDuring => 'Top spends · during';

  @override
  String get tripEdit => 'Edit trip';

  @override
  String get tripDelete => 'Delete trip';

  @override
  String get tripDeleteConfirm =>
      'Delete this trip permanently? All its transactions and categories will be erased. This cannot be undone.';

  @override
  String get cityFilter => 'Filter by category';

  @override
  String get cityFilterPlaceholder => 'all categories';

  @override
  String get secSplit => 'Shared vs your share';

  @override
  String get colDays => 'Days';

  @override
  String get colTotal => 'Total';

  @override
  String get colAvgDay => 'Avg/day';

  @override
  String get colTopCat => 'Top category';

  @override
  String get colCount => 'Count';

  @override
  String get colEntry => 'transaction';

  @override
  String get colEntries => 'transactions';

  @override
  String get colAvgTicket => 'Avg ticket';

  @override
  String get splitIntegral => 'Full value';

  @override
  String get splitShare => 'Your share';

  @override
  String get splitSavings => 'You saved';

  @override
  String get themeLight => 'Light theme';

  @override
  String get themeDark => 'Dark theme';

  @override
  String get txImportButton => 'Import';

  @override
  String get txImportTitle => 'Import transactions';

  @override
  String get txImportIntro =>
      'Paste your statement data (copied from your bank\'s site or a spreadsheet) or upload a .csv file. Nothing is imported until you review and confirm.';

  @override
  String get txImportPasteLabel => 'Paste your data here';

  @override
  String get txImportPastePlaceholder =>
      '03/12/2026\tUber\t45.90\n03/13/2026\tBakery\t12.00';

  @override
  String get txImportUploadButton => 'Or choose a file (.csv)';

  @override
  String get txImportDelimiter => 'Delimiter';

  @override
  String get txImportDelimiterAuto => 'Auto-detect';

  @override
  String get txImportDelimiterComma => 'Comma ( , )';

  @override
  String get txImportDelimiterSemicolon => 'Semicolon ( ; )';

  @override
  String get txImportDelimiterTab => 'Tab';

  @override
  String get txImportContinue => 'Continue';

  @override
  String get txImportNoRows =>
      'Couldn\'t find any data rows. Check the pasted text or the file.';

  @override
  String get txImportBack => 'Back';

  @override
  String get txImportHasHeader => 'First row is a header';

  @override
  String get txImportInvertSign => 'Invert value signs';

  @override
  String get txImportMapHint => 'Tell us what each column means:';

  @override
  String txImportColumnN(String n) {
    return 'Column $n';
  }

  @override
  String get txImportColIgnore => 'Ignore';

  @override
  String get txImportRowOk => 'ok';

  @override
  String get txImportErrAmount => 'invalid amount';

  @override
  String get txImportErrDescription => 'missing description';

  @override
  String get txImportErrDate => 'invalid date';

  @override
  String get txImportRowsReady => 'rows ready to import';

  @override
  String get txImportRowsSkipped => 'with issues (will not be imported)';

  @override
  String get txImportConfirmButton => 'Import';

  @override
  String get txImportSuccessSuffix => 'transactions imported.';

  @override
  String get txImportError => 'Could not import. Please try again.';
}

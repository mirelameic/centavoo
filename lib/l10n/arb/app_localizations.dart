import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_pt.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'arb/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('pt'),
    Locale('pt', 'BR'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In pt_BR, this message translates to:
  /// **'Centavoo'**
  String get appTitle;

  /// No description provided for @loading.
  ///
  /// In pt_BR, this message translates to:
  /// **'Preparando seus dados…'**
  String get loading;

  /// No description provided for @error.
  ///
  /// In pt_BR, this message translates to:
  /// **'Erro ao carregar os dados.'**
  String get error;

  /// No description provided for @tripsTitle.
  ///
  /// In pt_BR, this message translates to:
  /// **'Minhas viagens'**
  String get tripsTitle;

  /// No description provided for @tripsNew.
  ///
  /// In pt_BR, this message translates to:
  /// **'Nova viagem'**
  String get tripsNew;

  /// No description provided for @tripsEmpty.
  ///
  /// In pt_BR, this message translates to:
  /// **'Nenhuma viagem ainda.'**
  String get tripsEmpty;

  /// No description provided for @tripsCreateFirst.
  ///
  /// In pt_BR, this message translates to:
  /// **'Criar a primeira'**
  String get tripsCreateFirst;

  /// No description provided for @tripsNetSpend.
  ///
  /// In pt_BR, this message translates to:
  /// **'Gasto líquido'**
  String get tripsNetSpend;

  /// No description provided for @tripsMoveUp.
  ///
  /// In pt_BR, this message translates to:
  /// **'Mover para cima'**
  String get tripsMoveUp;

  /// No description provided for @tripsMoveDown.
  ///
  /// In pt_BR, this message translates to:
  /// **'Mover para baixo'**
  String get tripsMoveDown;

  /// No description provided for @formName.
  ///
  /// In pt_BR, this message translates to:
  /// **'Nome'**
  String get formName;

  /// No description provided for @formNamePlaceholder.
  ///
  /// In pt_BR, this message translates to:
  /// **'ex. Europa 2025'**
  String get formNamePlaceholder;

  /// No description provided for @formDestination.
  ///
  /// In pt_BR, this message translates to:
  /// **'Destino'**
  String get formDestination;

  /// No description provided for @formDestPlaceholder.
  ///
  /// In pt_BR, this message translates to:
  /// **'ex. Espanha · Grécia'**
  String get formDestPlaceholder;

  /// No description provided for @formDates.
  ///
  /// In pt_BR, this message translates to:
  /// **'Período'**
  String get formDates;

  /// No description provided for @formDatesPlaceholder.
  ///
  /// In pt_BR, this message translates to:
  /// **'início – fim'**
  String get formDatesPlaceholder;

  /// No description provided for @commonCancel.
  ///
  /// In pt_BR, this message translates to:
  /// **'Cancelar'**
  String get commonCancel;

  /// No description provided for @commonDelete.
  ///
  /// In pt_BR, this message translates to:
  /// **'Excluir'**
  String get commonDelete;

  /// No description provided for @commonCreate.
  ///
  /// In pt_BR, this message translates to:
  /// **'Criar'**
  String get commonCreate;

  /// No description provided for @commonBack.
  ///
  /// In pt_BR, this message translates to:
  /// **'Voltar'**
  String get commonBack;

  /// No description provided for @navTrips.
  ///
  /// In pt_BR, this message translates to:
  /// **'Viagens'**
  String get navTrips;

  /// No description provided for @kpiNet.
  ///
  /// In pt_BR, this message translates to:
  /// **'Líquido'**
  String get kpiNet;

  /// No description provided for @kpiGross.
  ///
  /// In pt_BR, this message translates to:
  /// **'Bruto'**
  String get kpiGross;

  /// No description provided for @kpiRefunds.
  ///
  /// In pt_BR, this message translates to:
  /// **'Reembolsos'**
  String get kpiRefunds;

  /// No description provided for @kpiBefore.
  ///
  /// In pt_BR, this message translates to:
  /// **'Antes'**
  String get kpiBefore;

  /// No description provided for @kpiDuring.
  ///
  /// In pt_BR, this message translates to:
  /// **'Durante'**
  String get kpiDuring;

  /// No description provided for @kpiAvgPerDay.
  ///
  /// In pt_BR, this message translates to:
  /// **'Média/dia'**
  String get kpiAvgPerDay;

  /// No description provided for @tabSummary.
  ///
  /// In pt_BR, this message translates to:
  /// **'Resumo'**
  String get tabSummary;

  /// No description provided for @tabTop.
  ///
  /// In pt_BR, this message translates to:
  /// **'Ranking'**
  String get tabTop;

  /// No description provided for @tabTransactions.
  ///
  /// In pt_BR, this message translates to:
  /// **'Transações'**
  String get tabTransactions;

  /// No description provided for @chartBefore.
  ///
  /// In pt_BR, this message translates to:
  /// **'Antes'**
  String get chartBefore;

  /// No description provided for @chartDuring.
  ///
  /// In pt_BR, this message translates to:
  /// **'Durante'**
  String get chartDuring;

  /// No description provided for @chartNoDated.
  ///
  /// In pt_BR, this message translates to:
  /// **'Sem gastos com data neste período.'**
  String get chartNoDated;

  /// No description provided for @chartNoCity.
  ///
  /// In pt_BR, this message translates to:
  /// **'Nenhuma transação com cidade ainda.'**
  String get chartNoCity;

  /// No description provided for @chartNoTop.
  ///
  /// In pt_BR, this message translates to:
  /// **'Nenhuma transação ainda.'**
  String get chartNoTop;

  /// No description provided for @cityPerDay.
  ///
  /// In pt_BR, this message translates to:
  /// **'Cidades por dia'**
  String get cityPerDay;

  /// No description provided for @cityPlaceholder.
  ///
  /// In pt_BR, this message translates to:
  /// **'cidade'**
  String get cityPlaceholder;

  /// No description provided for @cityList.
  ///
  /// In pt_BR, this message translates to:
  /// **'Cidades da viagem'**
  String get cityList;

  /// No description provided for @cityAddCity.
  ///
  /// In pt_BR, this message translates to:
  /// **'Adicionar cidade'**
  String get cityAddCity;

  /// No description provided for @cityRemoveCity.
  ///
  /// In pt_BR, this message translates to:
  /// **'Remover'**
  String get cityRemoveCity;

  /// No description provided for @cityBlockCityLabel.
  ///
  /// In pt_BR, this message translates to:
  /// **'Cidade'**
  String get cityBlockCityLabel;

  /// No description provided for @cityBlockRangeLabel.
  ///
  /// In pt_BR, this message translates to:
  /// **'Período'**
  String get cityBlockRangeLabel;

  /// No description provided for @cityAddBlock.
  ///
  /// In pt_BR, this message translates to:
  /// **'Adicionar período'**
  String get cityAddBlock;

  /// No description provided for @cityNoBlocks.
  ///
  /// In pt_BR, this message translates to:
  /// **'Nenhum período definido ainda.'**
  String get cityNoBlocks;

  /// No description provided for @cityDaysN.
  ///
  /// In pt_BR, this message translates to:
  /// **'dia(s)'**
  String get cityDaysN;

  /// No description provided for @cityUnassignedN.
  ///
  /// In pt_BR, this message translates to:
  /// **'dia(s) sem cidade'**
  String get cityUnassignedN;

  /// No description provided for @cityRemoveBlockConfirm.
  ///
  /// In pt_BR, this message translates to:
  /// **'Remover este período? Os dias ficam sem cidade.'**
  String get cityRemoveBlockConfirm;

  /// No description provided for @cityRemoveUsedWarning.
  ///
  /// In pt_BR, this message translates to:
  /// **'Remover mesmo assim vai deixar esses dias sem cidade. Continuar?'**
  String get cityRemoveUsedWarning;

  /// No description provided for @txDeleteSelected.
  ///
  /// In pt_BR, this message translates to:
  /// **'Excluir selecionadas'**
  String get txDeleteSelected;

  /// No description provided for @txSelectedN.
  ///
  /// In pt_BR, this message translates to:
  /// **'selecionadas'**
  String get txSelectedN;

  /// No description provided for @txDeleteSelectedConfirm.
  ///
  /// In pt_BR, this message translates to:
  /// **'Excluir as transações selecionadas?'**
  String get txDeleteSelectedConfirm;

  /// No description provided for @txSearchPlaceholder.
  ///
  /// In pt_BR, this message translates to:
  /// **'Buscar por descrição…'**
  String get txSearchPlaceholder;

  /// No description provided for @txFilterDate.
  ///
  /// In pt_BR, this message translates to:
  /// **'Data'**
  String get txFilterDate;

  /// No description provided for @txFilterDatePlaceholder.
  ///
  /// In pt_BR, this message translates to:
  /// **'qualquer data'**
  String get txFilterDatePlaceholder;

  /// No description provided for @txDateModeDay.
  ///
  /// In pt_BR, this message translates to:
  /// **'Dia'**
  String get txDateModeDay;

  /// No description provided for @txDateModeRange.
  ///
  /// In pt_BR, this message translates to:
  /// **'Período'**
  String get txDateModeRange;

  /// No description provided for @txFilterCategory.
  ///
  /// In pt_BR, this message translates to:
  /// **'Categoria'**
  String get txFilterCategory;

  /// No description provided for @txFilterCategoryPlaceholder.
  ///
  /// In pt_BR, this message translates to:
  /// **'todas as categorias'**
  String get txFilterCategoryPlaceholder;

  /// No description provided for @txFilterCity.
  ///
  /// In pt_BR, this message translates to:
  /// **'Cidade'**
  String get txFilterCity;

  /// No description provided for @txFilterCityPlaceholder.
  ///
  /// In pt_BR, this message translates to:
  /// **'todas as cidades'**
  String get txFilterCityPlaceholder;

  /// No description provided for @txFilterPeriod.
  ///
  /// In pt_BR, this message translates to:
  /// **'Período'**
  String get txFilterPeriod;

  /// No description provided for @txPeriodAll.
  ///
  /// In pt_BR, this message translates to:
  /// **'Todos'**
  String get txPeriodAll;

  /// No description provided for @txFilterResultsN.
  ///
  /// In pt_BR, this message translates to:
  /// **'resultado(s)'**
  String get txFilterResultsN;

  /// No description provided for @txClearFilters.
  ///
  /// In pt_BR, this message translates to:
  /// **'Limpar filtros'**
  String get txClearFilters;

  /// No description provided for @txSelect.
  ///
  /// In pt_BR, this message translates to:
  /// **'Selecionar'**
  String get txSelect;

  /// No description provided for @txCancelSelect.
  ///
  /// In pt_BR, this message translates to:
  /// **'Cancelar'**
  String get txCancelSelect;

  /// No description provided for @txSelectAll.
  ///
  /// In pt_BR, this message translates to:
  /// **'Selecionar todos'**
  String get txSelectAll;

  /// No description provided for @txClearSelection.
  ///
  /// In pt_BR, this message translates to:
  /// **'Limpar seleção'**
  String get txClearSelection;

  /// No description provided for @txDeleteOne.
  ///
  /// In pt_BR, this message translates to:
  /// **'Excluir'**
  String get txDeleteOne;

  /// No description provided for @txSortBy.
  ///
  /// In pt_BR, this message translates to:
  /// **'Ordenar por'**
  String get txSortBy;

  /// No description provided for @txSortDefault.
  ///
  /// In pt_BR, this message translates to:
  /// **'Padrão'**
  String get txSortDefault;

  /// No description provided for @tableDate.
  ///
  /// In pt_BR, this message translates to:
  /// **'Data'**
  String get tableDate;

  /// No description provided for @tableDescription.
  ///
  /// In pt_BR, this message translates to:
  /// **'Descrição'**
  String get tableDescription;

  /// No description provided for @tableCategory.
  ///
  /// In pt_BR, this message translates to:
  /// **'Categoria'**
  String get tableCategory;

  /// No description provided for @tableCity.
  ///
  /// In pt_BR, this message translates to:
  /// **'Cidade'**
  String get tableCity;

  /// No description provided for @tablePeriod.
  ///
  /// In pt_BR, this message translates to:
  /// **'Período'**
  String get tablePeriod;

  /// No description provided for @tableAmount.
  ///
  /// In pt_BR, this message translates to:
  /// **'Valor'**
  String get tableAmount;

  /// No description provided for @tableFull.
  ///
  /// In pt_BR, this message translates to:
  /// **'integral'**
  String get tableFull;

  /// No description provided for @periodBefore.
  ///
  /// In pt_BR, this message translates to:
  /// **'Antes'**
  String get periodBefore;

  /// No description provided for @periodDuring.
  ///
  /// In pt_BR, this message translates to:
  /// **'Durante'**
  String get periodDuring;

  /// No description provided for @tripNotFound.
  ///
  /// In pt_BR, this message translates to:
  /// **'Viagem não encontrada.'**
  String get tripNotFound;

  /// No description provided for @commonSave.
  ///
  /// In pt_BR, this message translates to:
  /// **'Salvar'**
  String get commonSave;

  /// No description provided for @commonEdit.
  ///
  /// In pt_BR, this message translates to:
  /// **'Editar'**
  String get commonEdit;

  /// No description provided for @txNew.
  ///
  /// In pt_BR, this message translates to:
  /// **'Nova transação'**
  String get txNew;

  /// No description provided for @txEdit.
  ///
  /// In pt_BR, this message translates to:
  /// **'Editar transação'**
  String get txEdit;

  /// No description provided for @txDeleteConfirm.
  ///
  /// In pt_BR, this message translates to:
  /// **'Excluir esta transação?'**
  String get txDeleteConfirm;

  /// No description provided for @fieldType.
  ///
  /// In pt_BR, this message translates to:
  /// **'Tipo'**
  String get fieldType;

  /// No description provided for @fieldSplit.
  ///
  /// In pt_BR, this message translates to:
  /// **'Dividir por'**
  String get fieldSplit;

  /// No description provided for @typeExpense.
  ///
  /// In pt_BR, this message translates to:
  /// **'Gasto'**
  String get typeExpense;

  /// No description provided for @typeRefund.
  ///
  /// In pt_BR, this message translates to:
  /// **'Reembolso'**
  String get typeRefund;

  /// No description provided for @typeIof.
  ///
  /// In pt_BR, this message translates to:
  /// **'Reembolso de IOF'**
  String get typeIof;

  /// No description provided for @menuCategories.
  ///
  /// In pt_BR, this message translates to:
  /// **'Categorias'**
  String get menuCategories;

  /// No description provided for @menuExport.
  ///
  /// In pt_BR, this message translates to:
  /// **'Exportar dados'**
  String get menuExport;

  /// No description provided for @menuImport.
  ///
  /// In pt_BR, this message translates to:
  /// **'Importar dados'**
  String get menuImport;

  /// No description provided for @catTitle.
  ///
  /// In pt_BR, this message translates to:
  /// **'Categorias'**
  String get catTitle;

  /// No description provided for @catNew.
  ///
  /// In pt_BR, this message translates to:
  /// **'Nova categoria'**
  String get catNew;

  /// No description provided for @catColor.
  ///
  /// In pt_BR, this message translates to:
  /// **'Cor'**
  String get catColor;

  /// No description provided for @catIcon.
  ///
  /// In pt_BR, this message translates to:
  /// **'Ícone'**
  String get catIcon;

  /// No description provided for @catEmpty.
  ///
  /// In pt_BR, this message translates to:
  /// **'Nenhuma categoria.'**
  String get catEmpty;

  /// No description provided for @catDeleteConfirm.
  ///
  /// In pt_BR, this message translates to:
  /// **'Excluir categoria? As transações dela ficam sem categoria.'**
  String get catDeleteConfirm;

  /// No description provided for @backupExportedOk.
  ///
  /// In pt_BR, this message translates to:
  /// **'Backup exportado.'**
  String get backupExportedOk;

  /// No description provided for @backupImportedOk.
  ///
  /// In pt_BR, this message translates to:
  /// **'Backup importado com sucesso.'**
  String get backupImportedOk;

  /// No description provided for @backupImportError.
  ///
  /// In pt_BR, this message translates to:
  /// **'Arquivo de backup inválido.'**
  String get backupImportError;

  /// No description provided for @backupExportError.
  ///
  /// In pt_BR, this message translates to:
  /// **'Não foi possível exportar o backup.'**
  String get backupExportError;

  /// No description provided for @tabTime.
  ///
  /// In pt_BR, this message translates to:
  /// **'Tempo'**
  String get tabTime;

  /// No description provided for @tabCities.
  ///
  /// In pt_BR, this message translates to:
  /// **'Cidades'**
  String get tabCities;

  /// No description provided for @tabCats.
  ///
  /// In pt_BR, this message translates to:
  /// **'Categorias'**
  String get tabCats;

  /// No description provided for @secCumulative.
  ///
  /// In pt_BR, this message translates to:
  /// **'Gasto acumulado'**
  String get secCumulative;

  /// No description provided for @secByDay.
  ///
  /// In pt_BR, this message translates to:
  /// **'Por dia'**
  String get secByDay;

  /// No description provided for @secWeekday.
  ///
  /// In pt_BR, this message translates to:
  /// **'Por dia da semana'**
  String get secWeekday;

  /// No description provided for @secByCity.
  ///
  /// In pt_BR, this message translates to:
  /// **'Por cidade'**
  String get secByCity;

  /// No description provided for @secCityTable.
  ///
  /// In pt_BR, this message translates to:
  /// **'Resumo por cidade'**
  String get secCityTable;

  /// No description provided for @secCatTable.
  ///
  /// In pt_BR, this message translates to:
  /// **'Resumo por categoria'**
  String get secCatTable;

  /// No description provided for @secBeforeDuring.
  ///
  /// In pt_BR, this message translates to:
  /// **'Antes × Durante'**
  String get secBeforeDuring;

  /// No description provided for @secTopBefore.
  ///
  /// In pt_BR, this message translates to:
  /// **'Maiores gastos · antes'**
  String get secTopBefore;

  /// No description provided for @secTopDuring.
  ///
  /// In pt_BR, this message translates to:
  /// **'Maiores gastos · durante'**
  String get secTopDuring;

  /// No description provided for @tripEdit.
  ///
  /// In pt_BR, this message translates to:
  /// **'Editar viagem'**
  String get tripEdit;

  /// No description provided for @tripDelete.
  ///
  /// In pt_BR, this message translates to:
  /// **'Excluir viagem'**
  String get tripDelete;

  /// No description provided for @tripDeleteConfirm.
  ///
  /// In pt_BR, this message translates to:
  /// **'Excluir esta viagem permanentemente? Todas as transações e categorias dela serão apagadas. Não dá pra desfazer.'**
  String get tripDeleteConfirm;

  /// No description provided for @cityFilter.
  ///
  /// In pt_BR, this message translates to:
  /// **'Filtrar por categoria'**
  String get cityFilter;

  /// No description provided for @cityFilterPlaceholder.
  ///
  /// In pt_BR, this message translates to:
  /// **'todas as categorias'**
  String get cityFilterPlaceholder;

  /// No description provided for @secSplit.
  ///
  /// In pt_BR, this message translates to:
  /// **'Você dividiu × sua parte'**
  String get secSplit;

  /// No description provided for @colDays.
  ///
  /// In pt_BR, this message translates to:
  /// **'Dias'**
  String get colDays;

  /// No description provided for @colTotal.
  ///
  /// In pt_BR, this message translates to:
  /// **'Total'**
  String get colTotal;

  /// No description provided for @colAvgDay.
  ///
  /// In pt_BR, this message translates to:
  /// **'Média/dia'**
  String get colAvgDay;

  /// No description provided for @colTopCat.
  ///
  /// In pt_BR, this message translates to:
  /// **'Top categoria'**
  String get colTopCat;

  /// No description provided for @colCount.
  ///
  /// In pt_BR, this message translates to:
  /// **'Nº'**
  String get colCount;

  /// No description provided for @colEntry.
  ///
  /// In pt_BR, this message translates to:
  /// **'transação'**
  String get colEntry;

  /// No description provided for @colEntries.
  ///
  /// In pt_BR, this message translates to:
  /// **'transações'**
  String get colEntries;

  /// No description provided for @colAvgTicket.
  ///
  /// In pt_BR, this message translates to:
  /// **'Ticket médio'**
  String get colAvgTicket;

  /// No description provided for @splitIntegral.
  ///
  /// In pt_BR, this message translates to:
  /// **'Valor integral'**
  String get splitIntegral;

  /// No description provided for @splitShare.
  ///
  /// In pt_BR, this message translates to:
  /// **'Sua parte'**
  String get splitShare;

  /// No description provided for @splitSavings.
  ///
  /// In pt_BR, this message translates to:
  /// **'Você economizou'**
  String get splitSavings;

  /// No description provided for @themeLight.
  ///
  /// In pt_BR, this message translates to:
  /// **'Tema claro'**
  String get themeLight;

  /// No description provided for @themeDark.
  ///
  /// In pt_BR, this message translates to:
  /// **'Tema escuro'**
  String get themeDark;

  /// No description provided for @txImportButton.
  ///
  /// In pt_BR, this message translates to:
  /// **'Importar'**
  String get txImportButton;

  /// No description provided for @txImportTitle.
  ///
  /// In pt_BR, this message translates to:
  /// **'Importar transações'**
  String get txImportTitle;

  /// No description provided for @txImportIntro.
  ///
  /// In pt_BR, this message translates to:
  /// **'Cole os dados da fatura (copiados do site do banco ou de uma planilha) ou envie um arquivo .csv. Nada é importado antes de você conferir e confirmar.'**
  String get txImportIntro;

  /// No description provided for @txImportPasteLabel.
  ///
  /// In pt_BR, this message translates to:
  /// **'Cole os dados aqui'**
  String get txImportPasteLabel;

  /// No description provided for @txImportPastePlaceholder.
  ///
  /// In pt_BR, this message translates to:
  /// **'12/03/2026\tUber\t45,90\n13/03/2026\tPadaria\t12,00'**
  String get txImportPastePlaceholder;

  /// No description provided for @txImportUploadButton.
  ///
  /// In pt_BR, this message translates to:
  /// **'Ou escolher um arquivo (.csv)'**
  String get txImportUploadButton;

  /// No description provided for @txImportDelimiter.
  ///
  /// In pt_BR, this message translates to:
  /// **'Separador'**
  String get txImportDelimiter;

  /// No description provided for @txImportDelimiterAuto.
  ///
  /// In pt_BR, this message translates to:
  /// **'Detectar automaticamente'**
  String get txImportDelimiterAuto;

  /// No description provided for @txImportDelimiterComma.
  ///
  /// In pt_BR, this message translates to:
  /// **'Vírgula ( , )'**
  String get txImportDelimiterComma;

  /// No description provided for @txImportDelimiterSemicolon.
  ///
  /// In pt_BR, this message translates to:
  /// **'Ponto e vírgula ( ; )'**
  String get txImportDelimiterSemicolon;

  /// No description provided for @txImportDelimiterTab.
  ///
  /// In pt_BR, this message translates to:
  /// **'Tab'**
  String get txImportDelimiterTab;

  /// No description provided for @txImportContinue.
  ///
  /// In pt_BR, this message translates to:
  /// **'Continuar'**
  String get txImportContinue;

  /// No description provided for @txImportNoRows.
  ///
  /// In pt_BR, this message translates to:
  /// **'Não encontrei nenhuma linha de dados. Verifique o texto colado ou o arquivo.'**
  String get txImportNoRows;

  /// No description provided for @txImportBack.
  ///
  /// In pt_BR, this message translates to:
  /// **'Voltar'**
  String get txImportBack;

  /// No description provided for @txImportHasHeader.
  ///
  /// In pt_BR, this message translates to:
  /// **'A primeira linha é um cabeçalho'**
  String get txImportHasHeader;

  /// No description provided for @txImportInvertSign.
  ///
  /// In pt_BR, this message translates to:
  /// **'Inverter sinal dos valores'**
  String get txImportInvertSign;

  /// No description provided for @txImportMapHint.
  ///
  /// In pt_BR, this message translates to:
  /// **'Diga o que cada coluna significa:'**
  String get txImportMapHint;

  /// No description provided for @txImportColumnN.
  ///
  /// In pt_BR, this message translates to:
  /// **'Coluna {n}'**
  String txImportColumnN(String n);

  /// No description provided for @txImportColIgnore.
  ///
  /// In pt_BR, this message translates to:
  /// **'Ignorar'**
  String get txImportColIgnore;

  /// No description provided for @txImportRowOk.
  ///
  /// In pt_BR, this message translates to:
  /// **'ok'**
  String get txImportRowOk;

  /// No description provided for @txImportErrAmount.
  ///
  /// In pt_BR, this message translates to:
  /// **'valor inválido'**
  String get txImportErrAmount;

  /// No description provided for @txImportErrDescription.
  ///
  /// In pt_BR, this message translates to:
  /// **'sem descrição'**
  String get txImportErrDescription;

  /// No description provided for @txImportErrDate.
  ///
  /// In pt_BR, this message translates to:
  /// **'data inválida'**
  String get txImportErrDate;

  /// No description provided for @txImportRowsReady.
  ///
  /// In pt_BR, this message translates to:
  /// **'linhas prontas para importar'**
  String get txImportRowsReady;

  /// No description provided for @txImportRowsSkipped.
  ///
  /// In pt_BR, this message translates to:
  /// **'com problema (não serão importadas)'**
  String get txImportRowsSkipped;

  /// No description provided for @txImportConfirmButton.
  ///
  /// In pt_BR, this message translates to:
  /// **'Importar'**
  String get txImportConfirmButton;

  /// No description provided for @txImportSuccessSuffix.
  ///
  /// In pt_BR, this message translates to:
  /// **'transações importadas.'**
  String get txImportSuccessSuffix;

  /// No description provided for @txImportError.
  ///
  /// In pt_BR, this message translates to:
  /// **'Não foi possível importar. Tente novamente.'**
  String get txImportError;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'pt'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when language+country codes are specified.
  switch (locale.languageCode) {
    case 'pt':
      {
        switch (locale.countryCode) {
          case 'BR':
            return AppLocalizationsPtBr();
        }
        break;
      }
  }

  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'pt':
      return AppLocalizationsPt();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}

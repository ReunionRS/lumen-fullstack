import 'dart:math';

import 'package:flutter/material.dart';

import '../../core/app_language.dart';
import '../../core/formatters.dart';
import '../../core/i18n.dart';
import '../../core/ui_tokens.dart';
import '../../models/finance_models.dart';
import '../../models/project_models.dart';
import '../../models/session_models.dart';
import '../../models/user_models.dart';
import '../../services/auth_service.dart';

class FinancesPage extends StatefulWidget {
  const FinancesPage({
    super.key,
    required this.auth,
    required this.projectId,
    required this.role,
    this.projectLabel,
  });

  final AuthService auth;
  final String? projectId;
  final String role;
  final String? projectLabel;

  @override
  State<FinancesPage> createState() => _FinancesPageState();
}

class _FinancesPageState extends State<FinancesPage> {
  final List<FinanceExpense> _expenses = [];
  final List<AppUser> _clients = [];
  final List<ProjectSummary> _projects = [];
  FinanceCategory? _categoryFilter;
  bool _loadingSelectors = false;
  bool _loadingExpenses = false;
  String? _error;
  String? _selectedClientId;
  String? _selectedProjectId;

  @override
  void initState() {
    super.initState();
    if (_isClient) {
      _selectedProjectId = widget.projectId;
      _loadExpenses();
    } else {
      _loadSelectors();
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: _FinancesScaffold(
        title: I18n.t('Финансы', 'Финансъёс', 'Finances'),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _needsSelection || _activeProjectId == null
              ? null
              : _openAddExpenseSheet,
          icon: const Icon(Icons.add),
          label: Text(I18n.t('Добавить', 'Сутыны', 'Add')),
          backgroundColor: UiTokens.accent,
          foregroundColor: Colors.black,
        ),
        body: TabBarView(
          children: [
            _buildExpensesTab(),
            _buildStatsTab(),
            _buildChartsTab(),
          ],
        ),
      ),
    );
  }

  String _t(String ru, String udm, String en, {String? tt, String? ba}) {
    return I18n.t(ru, udm, en, tt: tt, ba: ba);
  }

  bool get _isClient => widget.role == 'client';

  String? get _activeProjectId => _isClient ? widget.projectId : _selectedProjectId;

  bool get _needsSelection =>
      !_isClient && (_selectedClientId == null || _selectedProjectId == null);

  List<ProjectSummary> get _clientProjects {
    if (_selectedClientId == null) return const [];
    return _projects
        .where((p) => p.clientUserId == _selectedClientId)
        .toList(growable: false);
  }

  Future<void> _loadSelectors() async {
    setState(() {
      _loadingSelectors = true;
      _error = null;
    });

    try {
      final users = await widget.auth.fetchUsers();
      final projects = await widget.auth.fetchProjects();
      if (!mounted) return;
      setState(() {
        _clients
          ..clear()
          ..addAll(
            users.where((u) => u.role == 'client' && u.isActive && !u.isArchived),
          );
        _projects
          ..clear()
          ..addAll(projects);
      });
    } on UnauthorizedException {
      if (!mounted) return;
      setState(() => _error = _t('Сессия истекла. Войдите снова.', 'Сессия быдэ. Вновь пыры.', 'Session expired. Sign in again.', tt: 'Сессия тәмамланды. Кабат керегез.', ba: 'Сессия тамамланды. Ҡабат инегеҙ.'));
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loadingSelectors = false);
    }
  }

  Future<void> _loadExpenses() async {
    final projectId = _activeProjectId;
    if (projectId == null || projectId.isEmpty) {
      setState(() {
        _expenses.clear();
        _loadingExpenses = false;
        _error = null;
      });
      return;
    }

    setState(() {
      _loadingExpenses = true;
      _error = null;
    });

    try {
      final items = await widget.auth.fetchFinanceExpenses(
        projectId: projectId,
      );
      if (!mounted) return;
      setState(() {
        _expenses
          ..clear()
          ..addAll(items);
        _categoryFilter = null;
      });
    } on UnauthorizedException {
      if (!mounted) return;
      setState(() => _error = _t('Сессия истекла. Войдите снова.', 'Сессия быдэ. Вновь пыры.', 'Session expired. Sign in again.', tt: 'Сессия тәмамланды. Кабат керегез.', ba: 'Сессия тамамланды. Ҡабат инегеҙ.'));
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loadingExpenses = false);
    }
  }

  Widget _buildExpensesTab() {
    if (_loadingSelectors || _loadingExpenses) {
      return _LoadingState();
    }
    if (_error != null) {
      return _EmptyState(title: I18n.t('Ошибка', 'Йӧслык', 'Error'), subtitle: _error!);
    }
    if (_needsSelection) {
      return _buildSelectionView(
        title: _t('Сначала выберите клиента', 'Клиентез башта бырйы', 'Select a client first', tt: 'Башта клиентны сайлагыз', ba: 'Башта клиентты һайлағыҙ'),
        subtitle: I18n.t('После выбора клиента и объекта данные будут загружены', 'Клиент но объект бырйыса бере, даннайос грузитчозы', 'Data will load after selecting client and project'),
      );
    }
    if (_activeProjectId == null || _activeProjectId!.isEmpty) {
      return _EmptyState(
        title: I18n.t('Объект не выбран', 'Объект уг бырйы', 'Project not selected'),
        subtitle: I18n.t('Выберите объект, чтобы вести учет расходов', 'Узьытонлы объект бырйы', 'Choose a project to track expenses'),
      );
    }

    final expenses = _filteredExpenses();
    return RefreshIndicator(
      onRefresh: _loadExpenses,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
        children: [
          if (!_isClient && _selectedClientId != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                _clientLabel(_selectedClientId!),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: UiTokens.muted(context),
                ),
              ),
            ),
          if (!_isClient && _selectedProjectId != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(
                _projectLabel(_selectedProjectId!),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: UiTokens.muted(context),
                ),
              ),
            ),
          if (widget.projectLabel != null &&
              widget.projectLabel!.isNotEmpty &&
              _isClient)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(
                widget.projectLabel!,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: UiTokens.muted(context),
                ),
              ),
            ),
          _SummaryStrip(
            title: _t('Всего за месяц', 'Тазьы толэзь понна', 'Total this month', tt: 'Ай буенча барлыгы', ba: 'Ай буйынса дөйөм'),
            value: _formatCurrency(_totalForMonth(DateTime.now())),
            subtitle: '${_t('за', 'понна', 'for', tt: 'өчен', ba: 'өсөн')} ${_monthLabel(DateTime.now())}',
          ),
          const SizedBox(height: 16),
          Text(
            _t('Категории', 'Категорияос', 'Categories', tt: 'Категорияләр', ba: 'Категориялар'),
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: UiTokens.foreground(context),
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _FilterChip(
                label: _t('Все', 'Ваньмыз', 'All', tt: 'Барысы', ba: 'Барыһы'),
                selected: _categoryFilter == null,
                onTap: () => setState(() => _categoryFilter = null),
              ),
              ...FinanceCategory.values.map(
                (category) => _FilterChip(
                  label: category.label,
                  selected: _categoryFilter == category,
                  color: category.color,
                  onTap: () =>
                      setState(() => _categoryFilter = category),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            _t('Список расходов', 'Узьытонлэн лыдъёсыз', 'Expenses list', tt: 'Чыгымнар исемлеге', ba: 'Сығымдар исемлеге'),
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: UiTokens.foreground(context),
            ),
          ),
          const SizedBox(height: 10),
          if (expenses.isEmpty)
            _EmptyState(
              title: _t('Нет расходов', 'Узьытонъёс ӧвӧл', 'No expenses', tt: 'Чыгымнар юк', ba: 'Сығымдар юҡ'),
              subtitle: _t('Добавьте первую запись', 'Нырысь запись суты', 'Add your first entry', tt: 'Беренче язманы өстәгез', ba: 'Беренсе яҙманы өҫтәгеҙ'),
            )
          else
            ...expenses.map(_buildExpenseCard),
        ],
      ),
    );
  }

  Widget _buildStatsTab() {
    if (_loadingSelectors || _loadingExpenses) {
      return _LoadingState();
    }
    if (_error != null) {
      return _EmptyState(title: _t('Ошибка', 'Йӧслык', 'Error', tt: 'Хата', ba: 'Хата'), subtitle: _error!);
    }
    if (_needsSelection) {
      return _buildSelectionView(
        title: _t('Нужен клиент', 'Клиент кулэ', 'Client required', tt: 'Клиент кирәк', ba: 'Клиент кәрәк'),
        subtitle: _t('Выберите клиента и объект, чтобы видеть статистику', 'Статистиканы адӟыны клиент но объект бырйы', 'Select client and project to see statistics', tt: 'Статистиканы күрү өчен клиент һәм объект сайлагыз', ba: 'Статистиканы күреү өсөн клиент һәм объект һайлағыҙ'),
      );
    }
    if (_activeProjectId == null || _activeProjectId!.isEmpty) {
      return _EmptyState(
        title: _t('Объект не выбран', 'Объект уг бырйы', 'Project not selected', tt: 'Объект сайланмаган', ba: 'Объект һайланмаған'),
        subtitle: _t('Выберите объект, чтобы видеть статистику', 'Статистиканы адӟыны объект бырйы', 'Select project to see statistics', tt: 'Статистиканы күрү өчен объект сайлагыз', ba: 'Статистиканы күреү өсөн объект һайлағыҙ'),
      );
    }

    final now = DateTime.now();
    final totalsByCategory = _totalsByCategory();
    final totalMonth = _totalForMonth(now);
    final totalYear = _totalForYear(now.year);
    final averageMonth = _averageMonthlySpend(6);
    final topCategory = totalsByCategory.isEmpty
        ? null
        : totalsByCategory.entries.reduce(
            (a, b) => a.value >= b.value ? a : b,
          );

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
      children: [
        _SummaryGrid(
          items: [
            _SummaryTile(
              label: _t('Этот месяц', 'Та толэзь', 'This month', tt: 'Бу ай', ba: 'Был ай'),
              value: _formatCurrency(totalMonth),
              subtitle: _monthLabel(now),
            ),
            _SummaryTile(
              label: _t('Этот год', 'Та ар', 'This year', tt: 'Бу ел', ba: 'Быйыл'),
              value: _formatCurrency(totalYear),
              subtitle: '${now.year}',
            ),
            _SummaryTile(
              label: _t('Среднее / мес', 'Шӧд / толэзь', 'Average / month', tt: 'Уртача / ай', ba: 'Уртаса / ай'),
              value: _formatCurrency(averageMonth),
              subtitle: _t('за 6 мес', '6 толэзь понна', 'for 6 months', tt: '6 ай өчен', ba: '6 ай өсөн'),
            ),
            _SummaryTile(
              label: _t('Топ-категория', 'Вылысез категория', 'Top category', tt: 'Төп категория', ba: 'Төп категория'),
              value: topCategory?.key.label ?? '—',
              subtitle: topCategory == null
                  ? _t('Нет данных', 'Даннайос ӧвӧл', 'No data', tt: 'Мәгълүмат юк', ba: 'Мәғлүмәт юҡ')
                  : _formatCurrency(topCategory.value),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Text(
          _t('Структура расходов', 'Узьытон структура', 'Expense structure', tt: 'Чыгым структурасы', ba: 'Сығым структураһы'),
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: UiTokens.foreground(context),
          ),
        ),
        const SizedBox(height: 10),
        if (totalsByCategory.isEmpty)
          _EmptyState(
            title: _t('Нет данных', 'Даннайос ӧвӧл', 'No data', tt: 'Мәгълүмат юк', ba: 'Мәғлүмәт юҡ'),
            subtitle: _t('Добавьте расходы, чтобы видеть статистику', 'Статистикалы узьытонъёс суты', 'Add expenses to see statistics', tt: 'Статистиканы күрү өчен чыгым өстәгез', ba: 'Статистиканы күреү өсөн сығым өҫтәгеҙ'),
          )
        else
          ...totalsByCategory.entries.map(
            (entry) => _CategoryStatRow(
              category: entry.key,
              amount: entry.value,
              total: totalYear,
            ),
          ),
      ],
    );
  }

  Widget _buildChartsTab() {
    if (_loadingSelectors || _loadingExpenses) {
      return _LoadingState();
    }
    if (_error != null) {
      return _EmptyState(title: _t('Ошибка', 'Йӧслык', 'Error', tt: 'Хата', ba: 'Хата'), subtitle: _error!);
    }
    if (_needsSelection) {
      return _buildSelectionView(
        title: _t('Нужен клиент', 'Клиент кулэ', 'Client required', tt: 'Клиент кирәк', ba: 'Клиент кәрәк'),
        subtitle: _t('Выберите клиента и объект, чтобы строить графики', 'Графикъёс понна клиент но объект бырйы', 'Select client and project to build charts', tt: 'Графиклар өчен клиент һәм объект сайлагыз', ba: 'Графиктар өсөн клиент һәм объект һайлағыҙ'),
      );
    }
    if (_activeProjectId == null || _activeProjectId!.isEmpty) {
      return _EmptyState(
        title: _t('Объект не выбран', 'Объект уг бырйы', 'Project not selected', tt: 'Объект сайланмаган', ba: 'Объект һайланмаған'),
        subtitle: _t('Выберите объект, чтобы строить графики', 'Графикъёс понна объект бырйы', 'Select project to build charts', tt: 'Графиклар өчен объект сайлагыз', ba: 'Графиктар өсөн объект һайлағыҙ'),
      );
    }

    final monthly = _monthlyTotals(6);
    final byCategory = _totalsByCategory();
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
      children: [
        Text(
          _t('Динамика по месяцам', 'Толэзьёсын динамика', 'Monthly dynamics', tt: 'Айлар буенча динамика', ba: 'Айҙар буйынса динамика'),
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: UiTokens.foreground(context),
          ),
        ),
        const SizedBox(height: 12),
        _ChartCard(
          child: SizedBox(
            height: 180,
            child: _BarChart(
              labels: monthly.map((e) => e.label).toList(),
              values: monthly.map((e) => e.value).toList(),
              barColor: UiTokens.accent,
            ),
          ),
        ),
        const SizedBox(height: 20),
        Text(
          _t('Распределение по категориям', 'Категорияосъя люкаськон', 'Distribution by category', tt: 'Категорияләр буенча бүленеш', ba: 'Категориялар буйынса бүленеш'),
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: UiTokens.foreground(context),
          ),
        ),
        const SizedBox(height: 12),
        if (byCategory.isEmpty)
          _EmptyState(
            title: _t('Нет данных', 'Даннайос ӧвӧл', 'No data', tt: 'Мәгълүмат юк', ba: 'Мәғлүмәт юҡ'),
            subtitle: _t('Добавьте расходы для построения графика', 'График понна узьытонъёс суты', 'Add expenses to build chart', tt: 'График өчен чыгымнар өстәгез', ba: 'График өсөн сығымдар өҫтәгеҙ'),
          )
        else
          _ChartCard(
            child: Column(
              children: byCategory.entries.map((entry) {
                final total = _totalForYear(DateTime.now().year);
                final share = total == 0 ? 0.0 : entry.value / total;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _CategoryBar(
                    category: entry.key,
                    value: entry.value,
                    share: share,
                  ),
                );
              }).toList(),
            ),
          ),
      ],
    );
  }

  Widget _buildSelectionView({
    required String title,
    required String subtitle,
  }) {
    if (_clients.isEmpty) {
      return _EmptyState(
        title: _t('Нет клиентов', 'Клиентъёс ӧвӧл', 'No clients', tt: 'Клиентлар юк', ba: 'Клиенттар юҡ'),
        subtitle: _t('Сначала добавьте клиента в системе', 'Клиентез системае суты', 'Add a client to the system first', tt: 'Башта системага клиент өстәгез', ba: 'Башта системаға клиент өҫтәгеҙ'),
      );
    }

    final projects = _clientProjects;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: UiTokens.foreground(context),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          subtitle,
          style: TextStyle(color: UiTokens.muted(context)),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: UiTokens.card(context),
            borderRadius: BorderRadius.circular(18),
            boxShadow: UiTokens.cardShadow(context),
          ),
          child: Column(
            children: [
              DropdownButtonFormField<String>(
                value: _selectedClientId,
                items: _clients
                    .map(
                      (client) => DropdownMenuItem(
                        value: client.id,
                        child: Text(client.fio),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedClientId = value;
                    _selectedProjectId = null;
                    _expenses.clear();
                    _categoryFilter = null;
                  });
                },
                decoration: InputDecoration(labelText: _t('Клиент', 'Клиент', 'Client', tt: 'Клиент', ba: 'Клиент')),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _selectedProjectId,
                items: projects
                    .map(
                      (project) => DropdownMenuItem(
                        value: project.id,
                        child: Text(project.constructionAddress),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedProjectId = value;
                    _categoryFilter = null;
                  });
                  _loadExpenses();
                },
                decoration: InputDecoration(labelText: _t('Объект', 'Объект', 'Project', tt: 'Объект', ba: 'Объект')),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ],
    );
  }

  String _clientLabel(String id) {
    final match = _clients.where((c) => c.id == id);
    if (match.isEmpty) return _t('Клиент', 'Клиент', 'Client', tt: 'Клиент', ba: 'Клиент');
    return '${_t('Клиент', 'Клиент', 'Client', tt: 'Клиент', ba: 'Клиент')}: ${match.first.fio}';
  }

  String _projectLabel(String id) {
    final match = _projects.where((p) => p.id == id);
    if (match.isEmpty) return _t('Объект', 'Объект', 'Project', tt: 'Объект', ba: 'Объект');
    return '${_t('Объект', 'Объект', 'Project', tt: 'Объект', ba: 'Объект')}: ${match.first.constructionAddress}';
  }

  Widget _buildExpenseCard(FinanceExpense expense) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: UiTokens.card(context),
        borderRadius: BorderRadius.circular(16),
        boxShadow: UiTokens.cardShadow(context),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: expense.category.color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              expense.category.icon,
              color: expense.category.color,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  expense.category.label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: UiTokens.foreground(context),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  expense.note.isEmpty ? _t('Без комментария', 'Комментарийтэк', 'No comment', tt: 'Комментарий юк', ba: 'Комментарий юҡ') : expense.note,
                  style: TextStyle(color: UiTokens.muted(context)),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _formatCurrency(expense.amount),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: UiTokens.foreground(context),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                formatDateRu(expense.date.toIso8601String()),
                style: TextStyle(fontSize: 12, color: UiTokens.muted(context)),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, size: 18),
                color: UiTokens.muted(context),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                tooltip: _t('Удалить', 'Быдтыны', 'Delete', tt: 'Бетерү', ba: 'Юйырға'),
                onPressed: () => _confirmDelete(expense),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(FinanceExpense expense) async {
    final ok = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(_t('Удалить расход?', 'Узьытонез быдтыны?', 'Delete expense?', tt: 'Чыгымны бетерергәме?', ba: 'Сығымды юйырғамы?')),
            content: Text(
              '${expense.category.label}\n${_formatCurrency(expense.amount)}',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(_t('Отмена', 'Бертоны', 'Cancel', tt: 'Кире кагу', ba: 'Кире ҡағыу')),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(_t('Удалить', 'Быдтыны', 'Delete', tt: 'Бетерү', ba: 'Юйырға')),
              ),
            ],
          ),
        ) ??
        false;

    if (!ok) return;

    try {
      await widget.auth.deleteFinanceExpense(expense.id);
      if (!mounted) return;
      setState(() => _expenses.removeWhere((e) => e.id == expense.id));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
        ),
      );
    }
  }

  void _openAddExpenseSheet() {
    final amountController = TextEditingController();
    final noteController = TextEditingController();
    DateTime date = DateTime.now();
    FinanceCategory category = FinanceCategory.construction;
    bool saving = false;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return Container(
              padding: EdgeInsets.fromLTRB(
                20,
                20,
                20,
                20 + MediaQuery.of(ctx).viewInsets.bottom,
              ),
              decoration: BoxDecoration(
                color: UiTokens.card(ctx),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(24),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _t('Новый расход', 'Выль узьытон', 'New expense', tt: 'Яңа чыгым', ba: 'Яңы сығым'),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: UiTokens.foreground(ctx),
                    ),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<FinanceCategory>(
                    value: category,
                    items: FinanceCategory.values
                        .map(
                          (value) => DropdownMenuItem(
                            value: value,
                            child: Text(value.label),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value == null) return;
                      setModalState(() => category = value);
                    },
                    decoration: InputDecoration(
                      labelText: _t('Категория', 'Категория', 'Category', tt: 'Категория', ba: 'Категория'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: amountController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: _t('Сумма, ₽', 'Сумма, ₽', 'Amount, ₽', tt: 'Сумма, ₽', ba: 'Сумма, ₽'),
                      hintText: _t('Например, 12500', 'Мӥсаллы, 12500', 'For example, 12500', tt: 'Мәсәлән, 12500', ba: 'Мәҫәлән, 12500'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _DatePickerField(
                    label: _t('Дата', 'Нунал', 'Date', tt: 'Дата', ba: 'Дата'),
                    value: date,
                    onPick: () async {
                      final picked = await showDatePicker(
                        context: ctx,
                        initialDate: date,
                        firstDate: DateTime(date.year - 2),
                        lastDate: DateTime(date.year + 2),
                      );
                      if (picked == null) return;
                      setModalState(() => date = picked);
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: noteController,
                    maxLines: 2,
                    decoration: InputDecoration(
                      labelText: _t('Комментарий', 'Комментарий', 'Comment', tt: 'Комментарий', ba: 'Комментарий'),
                      hintText: _t('Например, закупка материалов', 'Мӥсаллы, материалъёс басьтон', 'For example, materials purchase', tt: 'Мәсәлән, материаллар сатып алу', ba: 'Мәҫәлән, материалдар һатып алыу'),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: saving
                          ? null
                          : () async {
                        final raw = amountController.text
                            .replaceAll(' ', '')
                            .replaceAll(',', '.');
                        final amount = double.tryParse(raw);
                        if (amount == null || amount <= 0) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(_t('Введите корректную сумму', 'Дӧзесь сумма пыртӥське', 'Enter a valid amount', tt: 'Дөрес сумманы кертегез', ba: 'Дөрөҫ сумма индерегеҙ')),
                            ),
                          );
                          return;
                        }
                        final projectId = _activeProjectId;
                        if (projectId == null || projectId.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(_t('Сначала выберите объект', 'Башта объект бырйы', 'Select project first', tt: 'Башта объектны сайлагыз', ba: 'Башта объектты һайлағыҙ')),
                            ),
                          );
                          return;
                        }
                        setModalState(() => saving = true);
                        try {
                          final expense =
                              await widget.auth.createFinanceExpense(
                            projectId: projectId,
                            category: category,
                            amount: amount,
                            date: date,
                            note: noteController.text.trim(),
                          );
                          if (!mounted) return;
                          setState(() {
                            _expenses.insert(0, expense);
                          });
                          Navigator.of(ctx).pop();
                        } catch (e) {
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(e
                                  .toString()
                                  .replaceFirst('Exception: ', '')),
                            ),
                          );
                        } finally {
                          if (mounted) {
                            setModalState(() => saving = false);
                          }
                        }
                      },
                      child: saving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(_t('Сохранить', 'Утчаны', 'Save', tt: 'Сакларга', ba: 'Һаҡларға')),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  List<FinanceExpense> _filteredExpenses() {
    final expenses = List.of(_expenses)
      ..sort((a, b) => b.date.compareTo(a.date));
    if (_categoryFilter == null) return expenses;
    return expenses.where((e) => e.category == _categoryFilter).toList();
  }

  Map<FinanceCategory, double> _totalsByCategory() {
    final totals = <FinanceCategory, double>{};
    for (final expense in _expenses) {
      totals.update(
        expense.category,
        (value) => value + expense.amount,
        ifAbsent: () => expense.amount,
      );
    }
    return totals;
  }

  double _totalForMonth(DateTime month) {
    final filtered = _expenses.where((e) =>
        e.date.year == month.year && e.date.month == month.month);
    return filtered.fold(0, (sum, e) => sum + e.amount);
  }

  double _totalForYear(int year) {
    return _expenses
        .where((e) => e.date.year == year)
        .fold(0, (sum, e) => sum + e.amount);
  }

  double _averageMonthlySpend(int months) {
    final monthly = _monthlyTotals(months);
    if (monthly.isEmpty) return 0;
    final total = monthly.fold<double>(0, (sum, e) => sum + e.value);
    return total / monthly.length;
  }

  List<_MonthlyTotal> _monthlyTotals(int months) {
    final now = DateTime.now();
    final items = <_MonthlyTotal>[];
    for (var i = months - 1; i >= 0; i--) {
      final date = DateTime(now.year, now.month - i, 1);
      items.add(
        _MonthlyTotal(
          label: _shortMonthLabel(date),
          value: _totalForMonth(date),
        ),
      );
    }
    return items;
  }

  String _monthLabel(DateTime date) {
    final language = AppLanguageStore.current;
    switch (language) {
      case AppLanguage.en:
        const months = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];
        return months[date.month - 1];
      case AppLanguage.tt:
        const months = ['гыйнвар', 'февраль', 'март', 'апрель', 'май', 'июнь', 'июль', 'август', 'сентябрь', 'октябрь', 'ноябрь', 'декабрь'];
        return months[date.month - 1];
      case AppLanguage.ba:
        const months = ['ғинуар', 'февраль', 'март', 'апрель', 'май', 'июнь', 'июль', 'август', 'сентябрь', 'октябрь', 'ноябрь', 'декабрь'];
        return months[date.month - 1];
      case AppLanguage.ru:
      case AppLanguage.udm:
        const months = ['январь', 'февраль', 'март', 'апрель', 'май', 'июнь', 'июль', 'август', 'сентябрь', 'октябрь', 'ноябрь', 'декабрь'];
        return months[date.month - 1];
    }
  }

  String _shortMonthLabel(DateTime date) {
    final language = AppLanguageStore.current;
    switch (language) {
      case AppLanguage.en:
        const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
        return months[date.month - 1];
      case AppLanguage.tt:
        const months = ['Гый', 'Фев', 'Мар', 'Апр', 'Май', 'Июн', 'Июл', 'Авг', 'Сен', 'Окт', 'Ноя', 'Дек'];
        return months[date.month - 1];
      case AppLanguage.ba:
        const months = ['Ғин', 'Фев', 'Мар', 'Апр', 'Май', 'Июн', 'Июл', 'Авг', 'Сен', 'Окт', 'Ноя', 'Дек'];
        return months[date.month - 1];
      case AppLanguage.ru:
      case AppLanguage.udm:
        const months = ['Янв', 'Фев', 'Мар', 'Апр', 'Май', 'Июн', 'Июл', 'Авг', 'Сен', 'Окт', 'Ноя', 'Дек'];
        return months[date.month - 1];
    }
  }

}

class _MonthlyTotal {
  const _MonthlyTotal({required this.label, required this.value});
  final String label;
  final double value;
}

class _SummaryStrip extends StatelessWidget {
  const _SummaryStrip({
    required this.title,
    required this.value,
    required this.subtitle,
  });

  final String title;
  final String value;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: UiTokens.card(context),
        borderRadius: BorderRadius.circular(18),
        boxShadow: UiTokens.cardShadow(context),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: UiTokens.accent.withOpacity(0.15),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.account_balance_wallet_outlined,
              color: UiTokens.accent,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: UiTokens.muted(context),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: UiTokens.foreground(context),
                  ),
                ),
              ],
            ),
          ),
          Text(
            subtitle,
            style: TextStyle(color: UiTokens.muted(context)),
          ),
        ],
      ),
    );
  }
}

class _SummaryTile extends StatelessWidget {
  const _SummaryTile({
    required this.label,
    required this.value,
    required this.subtitle,
  });

  final String label;
  final String value;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: UiTokens.card(context),
        borderRadius: BorderRadius.circular(16),
        boxShadow: UiTokens.cardShadow(context),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 12, color: UiTokens.muted(context)),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: UiTokens.foreground(context),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(fontSize: 11, color: UiTokens.muted(context)),
          ),
        ],
      ),
    );
  }
}

class _SummaryGrid extends StatelessWidget {
  const _SummaryGrid({required this.items});

  final List<Widget> items;

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 1.35,
      children: items,
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    this.color,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final Color? color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final chipColor = color ?? UiTokens.accent;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? chipColor.withOpacity(0.15) : UiTokens.card(context),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? chipColor : UiTokens.border(context),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: selected ? chipColor : UiTokens.muted(context),
          ),
        ),
      ),
    );
  }
}

class _CategoryStatRow extends StatelessWidget {
  const _CategoryStatRow({
    required this.category,
    required this.amount,
    required this.total,
  });

  final FinanceCategory category;
  final double amount;
  final double total;

  @override
  Widget build(BuildContext context) {
    final share = total == 0 ? 0.0 : amount / total;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: UiTokens.card(context),
        borderRadius: BorderRadius.circular(16),
        boxShadow: UiTokens.cardShadow(context),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: category.color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(category.icon, color: category.color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  category.label,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: UiTokens.foreground(context),
                  ),
                ),
                const SizedBox(height: 6),
                LinearProgressIndicator(
                  value: share,
                  minHeight: 6,
                  backgroundColor: UiTokens.surface(context),
                  color: category.color,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${(share * 100).toStringAsFixed(0)}%',
                style: TextStyle(
                  fontSize: 12,
                  color: UiTokens.muted(context),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _formatCurrency(amount),
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: UiTokens.foreground(context),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CategoryBar extends StatelessWidget {
  const _CategoryBar({
    required this.category,
    required this.value,
    required this.share,
  });

  final FinanceCategory category;
  final double value;
  final double share;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                category.label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: UiTokens.foreground(context),
                ),
              ),
            ),
            Text(
              _formatCurrency(value),
              style: TextStyle(color: UiTokens.muted(context)),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: share,
            minHeight: 8,
            backgroundColor: UiTokens.surface(context),
            color: category.color,
          ),
        ),
      ],
    );
  }
}

class _ChartCard extends StatelessWidget {
  const _ChartCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: UiTokens.card(context),
        borderRadius: BorderRadius.circular(16),
        boxShadow: UiTokens.cardShadow(context),
      ),
      child: child,
    );
  }
}

class _BarChart extends StatelessWidget {
  const _BarChart({
    required this.labels,
    required this.values,
    required this.barColor,
  });

  final List<String> labels;
  final List<double> values;
  final Color barColor;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _BarChartPainter(
        labels: labels,
        values: values,
        barColor: barColor,
        textColor: UiTokens.muted(context),
      ),
    );
  }
}

class _BarChartPainter extends CustomPainter {
  _BarChartPainter({
    required this.labels,
    required this.values,
    required this.barColor,
    required this.textColor,
  });

  final List<String> labels;
  final List<double> values;
  final Color barColor;
  final Color textColor;

  @override
  void paint(Canvas canvas, Size size) {
    final maxValue = values.isEmpty ? 1.0 : values.reduce(max).clamp(1, 1e12);
    final barWidth = size.width / max(values.length, 1);
    final paint = Paint()..color = barColor;
    final textStyle = TextStyle(fontSize: 11, color: textColor);

    for (var i = 0; i < values.length; i++) {
      final value = values[i];
      final barHeight = (value / maxValue) * (size.height - 24);
      final rect = Rect.fromLTWH(
        i * barWidth + barWidth * 0.2,
        size.height - barHeight - 18,
        barWidth * 0.6,
        barHeight,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(6)),
        paint,
      );

      final label = labels[i];
      final tp = TextPainter(
        text: TextSpan(text: label, style: textStyle),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: barWidth);
      tp.paint(
        canvas,
        Offset(i * barWidth + (barWidth - tp.width) / 2, size.height - 16),
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _DatePickerField extends StatelessWidget {
  const _DatePickerField({
    required this.label,
    required this.value,
    required this.onPick,
  });

  final String label;
  final DateTime value;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onPick,
      child: InputDecorator(
        decoration: InputDecoration(labelText: label),
        child: Text(formatDateRu(value.toIso8601String())),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: UiTokens.card(context),
        borderRadius: BorderRadius.circular(18),
        boxShadow: UiTokens.cardShadow(context),
      ),
      child: Column(
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: UiTokens.foreground(context),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(color: UiTokens.muted(context)),
          ),
        ],
      ),
    );
  }
}

class _LoadingState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: CircularProgressIndicator(
        color: UiTokens.accent,
      ),
    );
  }
}

class _FinancesScaffold extends StatelessWidget {
  const _FinancesScaffold({
    required this.title,
    required this.body,
    this.floatingActionButton,
  });

  final String title;
  final Widget body;
  final Widget? floatingActionButton;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: UiTokens.background(context),
      appBar: AppBar(
        title: Text(title),
        elevation: 0,
        backgroundColor: UiTokens.background(context),
        foregroundColor: UiTokens.foreground(context),
        bottom: TabBar(
          labelColor: UiTokens.foreground(context),
          unselectedLabelColor: UiTokens.muted(context),
          indicatorColor: UiTokens.accent,
          tabs: const [
            Tab(text: 'Расходы'),
            Tab(text: 'Статистика'),
            Tab(text: 'Графики'),
          ],
        ),
      ),
      floatingActionButton: floatingActionButton,
      body: body,
    );
  }
}

String _formatCurrency(double value) {
  final rounded = value.round();
  final raw = rounded.toString();
  final buffer = StringBuffer();
  var group = 0;
  for (var i = raw.length - 1; i >= 0; i--) {
    buffer.write(raw[i]);
    group++;
    if (i != 0 && group % 3 == 0) {
      buffer.write(' ');
    }
  }
  final formatted = buffer.toString().split('').reversed.join();
  return '$formatted ₽';
}

import 'package:lumora/core/ui/ui.dart';
import 'package:lumora/core/utils/l10n_ext.dart';
import 'package:lumora/features/home/presentation/launchers.dart';
import 'package:lumora/features/home/presentation/project_grid.dart';
import 'package:material_ui/material_ui.dart';

/// The Projects tab: every saved project with search and filter.
class ProjectsPage extends StatefulWidget {
  const ProjectsPage({super.key});

  @override
  State<ProjectsPage> createState() => _ProjectsPageState();
}

class _ProjectsPageState extends State<ProjectsPage> {
  ProjectFilter _filter = ProjectFilter.all;
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final bottom = MediaQuery.paddingOf(context).bottom;
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: GlassAppBar(title: Text(l.allProjects), showBack: false),
      body: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            sliver: SliverToBoxAdapter(
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _search,
                      onChanged: (_) => setState(() {}),
                      textInputAction: TextInputAction.search,
                      decoration: InputDecoration(
                        hintText: l.searchProjects,
                        prefixIcon: const Icon(Icons.search),
                        isDense: true,
                        suffixIcon: _search.text.isEmpty
                            ? null
                            : IconButton(
                                tooltip: l.clearSearch,
                                icon: const Icon(Icons.close),
                                onPressed: () => setState(_search.clear),
                              ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  ProjectFilterButton(value: _filter, onChanged: (f) => setState(() => _filter = f)),
                ],
              ),
            ),
          ),
          ProjectsSliver(filter: _filter, query: _search.text, onEmptyOpen: () => pickAndEditPhoto(context)),
          SliverToBoxAdapter(child: SizedBox(height: bottom + 24)),
        ],
      ),
    );
  }
}

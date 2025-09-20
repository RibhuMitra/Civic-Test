import 'package:flutter/material.dart';
import '../models/issue.dart';
import '../services/issue_service.dart';
import '../widgets/issue_card.dart';

class IssuesListScreen extends StatefulWidget {
  const IssuesListScreen({super.key});

  @override
  State<IssuesListScreen> createState() => _IssuesListScreenState();
}

class _IssuesListScreenState extends State<IssuesListScreen> {
  final _issueService = IssueService();
  List<Issue> _issues = [];
  bool _isLoading = true;
  String _sortBy = 'created_at';

  @override
  void initState() {
    super.initState();
    _loadIssues();
  }

  Future<void> _loadIssues() async {
    setState(() => _isLoading = true);
    try {
      final issues = await _issueService.getIssues(
        sortBy: _sortBy,
        descending: true,
      );
      setState(() => _issues = issues);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading issues: $e')),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // Sort options
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                const Text('Sort by:'),
                const SizedBox(width: 16),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(
                      value: 'created_at',
                      label: Text('Recent'),
                      icon: Icon(Icons.schedule),
                    ),
                    ButtonSegment(
                      value: 'votes_count',
                      label: Text('Popular'),
                      icon: Icon(Icons.thumb_up),
                    ),
                  ],
                  selected: {_sortBy},
                  onSelectionChanged: (Set<String> newSelection) {
                    setState(() {
                      _sortBy = newSelection.first;
                    });
                    _loadIssues();
                  },
                ),
              ],
            ),
          ),

          // Issues list
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: _loadIssues,
                    child: _issues.isEmpty
                        ? const Center(
                            child: Text('No issues reported yet'),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: _issues.length,
                            itemBuilder: (context, index) {
                              return IssueCard(issue: _issues[index]);
                            },
                          ),
                  ),
          ),
        ],
      ),
    );
  }
}

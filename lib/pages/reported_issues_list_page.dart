import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/issue_service.dart';
import '../models/reported_issue.dart';

/// Page for admins to view and manage reported issues
class ReportedIssuesListPage extends StatefulWidget {
  const ReportedIssuesListPage({super.key});

  @override
  State<ReportedIssuesListPage> createState() => _ReportedIssuesListPageState();
}

class _ReportedIssuesListPageState extends State<ReportedIssuesListPage>
    with AutomaticKeepAliveClientMixin {
  final _issueService = IssueService();
  List<ReportedIssue> _issues = [];
  bool _isLoading = true;
  String? _selectedStatusFilter;

  final List<String> _statusFilters = [
    'All',
    'pending',
    'in_progress',
    'resolved',
    'rejected',
  ];

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadIssues();
  }

  Future<void> _loadIssues() async {
    setState(() => _isLoading = true);
    try {
      final issues = await _issueService.getAllIssues(
        statusFilter: _selectedStatusFilter,
      );
      setState(() {
        _issues = issues;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading issues: $e')));
      }
    }
  }

  Future<void> _updateStatus(String issueId, String newStatus) async {
    try {
      await _issueService.updateIssueStatus(issueId, newStatus);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Status updated successfully')),
        );
        _loadIssues(); // Reload
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  void _showStatusDialog(ReportedIssue issue) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Update Issue Status'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('Pending'),
              leading: Radio<String>(
                value: 'pending',
                groupValue: issue.status,
                onChanged: (v) {
                  Navigator.pop(context);
                  _updateStatus(issue.id!, 'pending');
                },
              ),
            ),
            ListTile(
              title: const Text('In Progress'),
              leading: Radio<String>(
                value: 'in_progress',
                groupValue: issue.status,
                onChanged: (v) {
                  Navigator.pop(context);
                  _updateStatus(issue.id!, 'in_progress');
                },
              ),
            ),
            ListTile(
              title: const Text('Resolved'),
              leading: Radio<String>(
                value: 'resolved',
                groupValue: issue.status,
                onChanged: (v) {
                  Navigator.pop(context);
                  _updateStatus(issue.id!, 'resolved');
                },
              ),
            ),
            ListTile(
              title: const Text('Rejected'),
              leading: Radio<String>(
                value: 'rejected',
                groupValue: issue.status,
                onChanged: (v) {
                  Navigator.pop(context);
                  _updateStatus(issue.id!, 'rejected');
                },
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending':
        return Colors.orange;
      case 'in_progress':
        return Colors.blue;
      case 'resolved':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Reported Issues',
          style: GoogleFonts.urbanist(color: Colors.white),
        ),
        backgroundColor: const Color(0xff0c1c2c),
        foregroundColor: Colors.white,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadIssues),
        ],
      ),
      body: Column(
        children: [
          // Status filter dropdown
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.grey[100],
            child: Row(
              children: [
                Text(
                  'Filter by status:',
                  style: GoogleFonts.urbanist(fontWeight: FontWeight.w500),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButton<String?>(
                    value: _selectedStatusFilter,
                    isExpanded: true,
                    items: _statusFilters.map((status) {
                      return DropdownMenuItem<String?>(
                        value: status == 'All' ? null : status,
                        child: Text(
                          status == 'All'
                              ? 'All'
                              : status.replaceAll('_', ' ').toUpperCase(),
                        ),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedStatusFilter = value;
                      });
                      _loadIssues();
                    },
                  ),
                ),
              ],
            ),
          ),
          // Issues list
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _issues.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.inbox, size: 64, color: Colors.grey[400]),
                        const SizedBox(height: 16),
                        Text(
                          'No issues found',
                          style: GoogleFonts.urbanist(
                            fontSize: 18,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _loadIssues,
                    child: ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _issues.length,
                      itemBuilder: (context, index) {
                        final issue = _issues[index];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          elevation: 2,
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        issue.title,
                                        style: GoogleFonts.urbanist(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: _getStatusColor(
                                          issue.status,
                                        ).withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: _getStatusColor(issue.status),
                                        ),
                                      ),
                                      child: Text(
                                        issue.statusDisplay,
                                        style: TextStyle(
                                          color: _getStatusColor(issue.status),
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  issue.description,
                                  style: GoogleFonts.urbanist(
                                    fontSize: 14,
                                    color: Colors.grey[700],
                                  ),
                                ),
                                const Divider(height: 24),
                                Row(
                                  children: [
                                    Icon(
                                      Icons.person,
                                      size: 16,
                                      color: Colors.grey[600],
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      issue.reporterName ?? 'Unknown',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Icon(
                                      Icons.email,
                                      size: 16,
                                      color: Colors.grey[600],
                                    ),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: Text(
                                        issue.reporterEmail ?? 'N/A',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey[600],
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Icon(
                                      Icons.access_time,
                                      size: 16,
                                      color: Colors.grey[600],
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      issue.createdAt != null
                                          ? _formatDate(issue.createdAt!)
                                          : 'Unknown',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                    const Spacer(),
                                    TextButton.icon(
                                      onPressed: () => _showStatusDialog(issue),
                                      icon: const Icon(Icons.edit, size: 16),
                                      label: const Text('Update Status'),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays > 7) {
      return '${date.day}/${date.month}/${date.year}';
    } else if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }
}

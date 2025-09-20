import 'package:flutter/material.dart';

class VoteButton extends StatelessWidget {
  final String issueId;
  final int votesCount;
  final bool hasVoted;
  final VoidCallback onVote;
  final bool isLoading;

  const VoteButton({
    super.key,
    required this.issueId,
    required this.votesCount,
    required this.hasVoted,
    required this.onVote,
    required this.isLoading,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: hasVoted || isLoading ? null : onVote,
      icon: Icon(
        hasVoted ? Icons.thumb_up : Icons.thumb_up_outlined,
        size: 18,
        color: hasVoted ? Colors.blue : null,
      ),
      label: isLoading
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Text(
              '$votesCount vote${votesCount != 1 ? 's' : ''}',
              style: TextStyle(
                color: hasVoted ? Colors.blue : null,
                fontWeight: hasVoted ? FontWeight.bold : null,
              ),
            ),
      style: OutlinedButton.styleFrom(
        side: BorderSide(
          color: hasVoted ? Colors.blue : Colors.grey,
        ),
        backgroundColor: hasVoted ? Colors.blue.withOpacity(0.1) : null,
      ),
    );
  }
}

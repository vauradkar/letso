import 'package:flutter/material.dart';
import 'package:letso/data.dart';

typedef DataRowCallback = void Function(SyncPath, String action);

class SyncedDirectorySetting extends StatelessWidget {
  final List<SyncPath> dataFuture;
  final DataRowCallback onActionPressed;

  const SyncedDirectorySetting({
    super.key,
    required this.dataFuture,
    required this.onActionPressed,
  });

  @override
  Widget build(BuildContext context) {
    return _buildDataTable(dataFuture);
  }

  Widget _buildDataTable(List<SyncPath> data) {
    return SingleChildScrollView(
      child: Column(
        children: [
          _buildTableHeader(),
          ...data.asMap().entries.map((entry) {
            final index = entry.key;
            final item = entry.value;
            return _buildDataRow(item, index % 2 == 0);
          }),
        ],
      ),
    );
  }

  Widget _buildTableHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade300, width: 1),
        ),
      ),
      child: Row(
        children: [
          _buildHeaderCell('Local', flex: 4),
          _buildHeaderCell('Remote', flex: 4),
          _buildHeaderCell('Actions', flex: 2),
        ],
      ),
    );
  }

  Widget _buildHeaderCell(String title, {int flex = 1}) {
    return Expanded(
      flex: flex,
      child: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: Colors.grey.shade700,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildDataRow(SyncPath data, bool isEven) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
      decoration: BoxDecoration(
        color: isEven ? Colors.white : Colors.grey.shade50,
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade200, width: 0.5),
        ),
      ),
      child: Row(
        children: [
          _buildDataCell(data.local.toString(), flex: 30),
          _buildDataCell(data.remote.toString(), flex: 30),
          _buildActionButtons(data, flex: 40),
        ],
      ),
    );
  }

  Widget _buildDataCell(String text, {int flex = 1}) {
    return Expanded(
      flex: flex,
      child: Text(
        text,
        style: TextStyle(
          fontSize: 14,
          color: Colors.grey.shade800,
          fontWeight: FontWeight.w500,
        ),
        overflow: TextOverflow.fade,
      ),
    );
  }

  Widget _buildActionButtons(SyncPath data, {int flex = 2}) {
    return Expanded(
      flex: flex,
      child: Row(
        children: [
          _buildActionButton(
            icon: Icons.delete_outline,
            label: 'Delete',
            color: Colors.red.shade600,
            onPressed: () => onActionPressed(data, 'delete'),
          ),
          const SizedBox(width: 8),
          _buildActionButton(
            icon: Icons.sync,
            label: 'Sync',
            color: Colors.green.shade600,
            onPressed: () => onActionPressed(data, 'sync'),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return Expanded(
      child: IconButton(
        onPressed: onPressed,
        icon: Icon(icon, size: 16),
        // label: Text(
        //   label,
        //   style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        // ),
        style: ElevatedButton.styleFrom(
          foregroundColor: Colors.white,
          backgroundColor: color,
          elevation: 2,
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          minimumSize: const Size(0, 36),
        ),
      ),
    );
  }
}

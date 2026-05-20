import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:t2t_admin/models/student_model.dart';
import 'package:t2t_admin/view/student_details.dart';

final studentsProvider = FutureProvider<List<StudentModel>>((ref) async {
  final snapshot = await FirebaseFirestore.instance
      .collection('students')
      .get();
  return snapshot.docs
      .map((doc) => StudentModel.fromMap(doc.data(), doc.id))
      .toList();
});

class StudentsScreen extends ConsumerStatefulWidget {
  const StudentsScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<StudentsScreen> createState() => _StudentsScreenState();
}

class _StudentsScreenState extends ConsumerState<StudentsScreen> with TickerProviderStateMixin {
  final _searchController = TextEditingController();
  List<StudentModel> _students = [];
  int _sortColumnIndex = 0;
  bool _sortAscending = true;
  
  late final AnimationController _iconController;
  late final Animation<double> _iconRotationAnim;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_filterStudents);
    
    _iconController = AnimationController(vsync: this, duration: const Duration(seconds: 8));
    _iconRotationAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _iconController, curve: Curves.linear)
    );
    _iconController.repeat();
  }

  void _filterStudents() {
    setState(() {}); // triggers rebuild which recomputes display from search query
  }

  void _sort<T>(Comparable<T> Function(StudentModel s) getField, int columnIndex, bool ascending) {
    setState(() {
      _students.sort((a, b) {
        final aValue = getField(a);
        final bValue = getField(b);
        return ascending ? Comparable.compare(aValue, bValue) : Comparable.compare(bValue, aValue);
      });
      _sortColumnIndex = columnIndex;
      _sortAscending = ascending;
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _iconController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final studentsAsync = ref.watch(studentsProvider);
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: const Color(0xFFE8F5E9),
      extendBodyBehindAppBar: false,
      body: SafeArea(
        child: Column(
          children: [
                  // Custom AppBar
                  Container(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: const BoxDecoration(
                            color: Color(0xFFE8F5E9),
                            borderRadius: BorderRadius.all(Radius.circular(12)),
                            boxShadow: [
                              BoxShadow(color: Color(0xFFC3D4C5), offset: Offset(4, 4), blurRadius: 10),
                              BoxShadow(color: Colors.white, offset: Offset(-4, -4), blurRadius: 10),
                            ],
                          ),
                          child: const Icon(
                            Icons.group,
                            color: Color(0xFF2E7D32),
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Students',
                          style: t.headlineMedium?.copyWith(
                            color: const Color(0xFF1B5E20),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  // Content
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          // Search bar
                          Container(
                            decoration: const BoxDecoration(
                              color: Color(0xFFE8F5E9),
                              borderRadius: BorderRadius.all(Radius.circular(16)),
                              boxShadow: [
                                BoxShadow(color: Color(0xFFC3D4C5), offset: Offset(-4, -4), blurRadius: 10),
                                BoxShadow(color: Colors.white, offset: Offset(4, 4), blurRadius: 10),
                              ],
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: TextField(
                                controller: _searchController,
                                style: const TextStyle(
                                  color: Color(0xFF1B5E20),
                                  fontSize: 16,
                                ),
                                decoration: InputDecoration(
                                  hintText: 'Search by name or ID...',
                                  hintStyle: TextStyle(
                                    color: Colors.grey.shade500,
                                  ),
                                  prefixIcon: const Icon(
                                    Icons.search,
                                    color: Color(0xFF2E7D32),
                                  ),
                                  border: InputBorder.none,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          
                          // Students table
                          Expanded(
                            child: Container(
                              decoration: const BoxDecoration(
                                color: Color(0xFFE8F5E9),
                                borderRadius: BorderRadius.all(Radius.circular(20)),
                                boxShadow: [
                                  BoxShadow(
                                    color: Color(0xFFC3D4C5),
                                    offset: Offset(6, 6),
                                    blurRadius: 15,
                                    spreadRadius: 1,
                                  ),
                                  BoxShadow(
                                    color: Colors.white,
                                    offset: Offset(-6, -6),
                                    blurRadius: 15,
                                    spreadRadius: 1,
                                  ),
                                ],
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: studentsAsync.when(
                                  data: (students) {
                                    // Sync full list
                                    if (_students != students) {
                                      _students = students;
                                    }
                                    // Compute display list from search query
                                    final query = _searchController.text.toLowerCase();
                                    final display = query.isEmpty
                                        ? _students
                                        : _students.where((s) =>
                                            s.fullName.toLowerCase().contains(query) ||
                                            s.studentID.toLowerCase().contains(query)).toList();
                                    
                                    if (display.isEmpty) {
                                      return Center(
                                        child: Column(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              Icons.people_outline,
                                              size: 64,
                                              color: Colors.grey.shade400,
                                            ),
                                            const SizedBox(height: 16),
                                            Text(
                                              'No students found',
                                              style: TextStyle(
                                                color: Colors.grey.shade600,
                                                fontSize: 18,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                            const SizedBox(height: 8),
                                            Text(
                                              'Total students loaded: ${students.length}',
                                              style: TextStyle(
                                                color: Colors.grey.shade500,
                                                fontSize: 14,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              'Search query: "${_searchController.text}"',
                                              style: TextStyle(
                                                color: Colors.grey.shade500,
                                                fontSize: 14,
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    }
                                    
                                    return Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.all(8),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFF4CAF50).withOpacity(0.1),
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                              child: Icon(
                                                Icons.list,
                                                color: const Color(0xFF4CAF50),
                                                size: 20,
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            Text(
                                              'Students List (${display.length})',
                                              style: t.headlineSmall?.copyWith(
                                                color: const Color(0xFF2E7D32),
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 16),
                                        Expanded(
                                          child: SingleChildScrollView(
                                            child: SingleChildScrollView(
                                              scrollDirection: Axis.horizontal,
                                              child: DataTable(
                                              sortColumnIndex: _sortColumnIndex,
                                              sortAscending: _sortAscending,
                                              headingTextStyle: TextStyle(
                                                color: const Color(0xFF2E7D32),
                                                fontWeight: FontWeight.w700,
                                                fontSize: 14,
                                              ),
                                              dataTextStyle: TextStyle(
                                                color: Colors.grey.shade800,
                                                fontSize: 13,
                                              ),
                                              columns: [
                                                DataColumn(
                                                  label: const Text('Name'),
                                                  onSort: (columnIndex, ascending) => _sort((s) => s.fullName, columnIndex, ascending),
                                                ),
                                                DataColumn(
                                                  label: const Text('Student ID'),
                                                  onSort: (columnIndex, ascending) => _sort((s) => s.studentID, columnIndex, ascending),
                                                ),
                                                DataColumn(
                                                  label: const Text('Department'),
                                                  onSort: (columnIndex, ascending) => _sort((s) => s.department, columnIndex, ascending),
                                                ),
                                                DataColumn(
                                                  label: const Text('Bottles'),
                                                  numeric: true,
                                                  onSort: (columnIndex, ascending) => _sort((s) => s.bottles, columnIndex, ascending),
                                                ),
                                                DataColumn(
                                                  label: const Text('Points'),
                                                  numeric: true,
                                                  onSort: (columnIndex, ascending) => _sort((s) => s.points, columnIndex, ascending),
                                                ),
                                                const DataColumn(label: Text('Joined')),
                                              ],
                                              rows: display.map((student) {
                                                return DataRow(
                                                  cells: [
                                                    DataCell(
                                                      Text(
                                                        student.fullName,
                                                        style: TextStyle(
                                                          color: Colors.grey.shade800,
                                                          fontWeight: FontWeight.w600,
                                                        ),
                                                      ),
                                                    ),
                                                    DataCell(
                                                      Text(
                                                        student.studentID,
                                                        style: TextStyle(
                                                          color: const Color(0xFF4CAF50),
                                                          fontWeight: FontWeight.w500,
                                                        ),
                                                      ),
                                                    ),
                                                    DataCell(
                                                      Text(
                                                        student.department,
                                                        style: TextStyle(
                                                          color: Colors.grey.shade600,
                                                        ),
                                                      ),
                                                    ),
                                                    DataCell(
                                                      Container(
                                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                        decoration: BoxDecoration(
                                                          color: Colors.blue.withOpacity(0.1),
                                                          borderRadius: BorderRadius.circular(8),
                                                        ),
                                                        child: Text(
                                                          student.bottles.toString(),
                                                          style: TextStyle(
                                                            color: Colors.blue.shade700,
                                                            fontWeight: FontWeight.w600,
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                    DataCell(
                                                      Container(
                                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                        decoration: BoxDecoration(
                                                          color: const Color(0xFF4CAF50).withOpacity(0.1),
                                                          borderRadius: BorderRadius.circular(8),
                                                        ),
                                                        child: Text(
                                                          student.points.toString(),
                                                          style: TextStyle(
                                                            color: const Color(0xFF4CAF50),
                                                            fontWeight: FontWeight.w600,
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                    DataCell(
                                                      Text(
                                                        student.createdAt.toDate().toString().substring(0, 10),
                                                        style: TextStyle(
                                                          color: Colors.grey.shade500,
                                                          fontSize: 12,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                  onSelectChanged: (selected) {
                                                    if (selected ?? false) {
                                                      Navigator.push(
                                                        context,
                                                        MaterialPageRoute(
                                                          builder: (context) => StudentDetailsScreen(student: student),
                                                        ),
                                                      );
                                                    }
                                                  },
                                                );
                                              }).toList(),
                                            ),
                                          ),
                                        ),
                                        ),
                                      ],
                                    );
                                  },
                                  loading: () => Center(
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        const CircularProgressIndicator(
                                          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF4CAF50)),
                                        ),
                                        const SizedBox(height: 16),
                                        Text(
                                          'Loading students...',
                                          style: TextStyle(
                                            color: Colors.grey.shade600,
                                            fontSize: 16,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  error: (err, stack) => Center(
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.error_outline,
                                          size: 64,
                                          color: Colors.red.shade400,
                                        ),
                                        const SizedBox(height: 16),
                                        Text(
                                          'Error loading students',
                                          style: TextStyle(
                                            color: Colors.red.shade600,
                                            fontSize: 18,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          err.toString(),
                                          style: TextStyle(
                                            color: Colors.grey.shade600,
                                            fontSize: 14,
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                        const SizedBox(height: 16),
                                        ElevatedButton(
                                          onPressed: () {
                                            // Refresh the provider
                                            ref.invalidate(studentsProvider);
                                          },
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: const Color(0xFF4CAF50),
                                            foregroundColor: Colors.white,
                                          ),
                                          child: const Text('Retry'),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}


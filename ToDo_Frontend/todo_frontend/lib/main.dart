import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;

void main() {
  runApp(const MyTurnApp());
}

class MyTurnApp extends StatelessWidget {
  const MyTurnApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        scaffoldBackgroundColor: const Color(0xFF090909),
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late DateTime _currentMonday;
  List<Map<String, dynamic>> _weekDays = [];
  bool _isLoadingWeek = true;
  bool _isLoadingTasks = false;
  bool _isCompletedSectionExpanded = true;
  bool _showDeleteConfirmation = true;

  late DateTime _selectedDate;
  final TextEditingController _searchController = TextEditingController();
  
  List<Map<String, dynamic>> _allTasksForSelectedDay = [];
  List<Map<String, dynamic>> _filteredTasks = [];
  String _quoteText = "LOADING...";
  String _quoteAuthor = "";

  @override
  void initState() {
    super.initState();
    final DateTime now = DateTime.now();
    _selectedDate = DateTime(now.year, now.month, now.day); 
    _initCurrentWeek();
    _fetchTodayQuote();
    _fetchWeekStatus();
    _fetchTasksForDay(_selectedDate);

    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredTasks = _allTasksForSelectedDay.where((task) {
        final taskName = (task['name'] as String).toLowerCase();
        return taskName.contains(query);
      }).toList();
    });
  }

  void _initCurrentWeek() {
    final DateTime now = DateTime.now();
    _currentMonday = DateTime(now.year, now.month, now.day).subtract(Duration(days: now.weekday - 1));
  }

  static Color parseHexColor(String hexColorString) {
    String hex = hexColorString.replaceAll('#', '').toUpperCase().trim();
    if (hex.isEmpty) return const Color(0xFF81C784);

    if (hex.length == 6) {
      hex = 'FF$hex';
    }
    
    try {
      return Color(int.parse('0x$hex'));
    } catch (_) {
      return const Color(0xFF81C784);
    }
  }

  void _fetchTasksForDay(DateTime date) async {
    setState(() {
      _isLoadingTasks = true;
    });
    try {
      final String formattedDate = DateFormat('yyyy-MM-dd').format(date);
      final url = Uri.parse('http://localhost:3145/tasks?date=$formattedDate');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(utf8.decode(response.bodyBytes));
        List<Map<String, dynamic>> parsedTasks = data.map((t) {
          return {
            'id': t['id'],
            'name': t['name'] ?? '',
            'isCompleted': t['isCompleted'] ?? false,
            'description': t['description'] ?? '',
            'priorityName': t['priority'] ?? 'LOW',
            'priorityColor': t['hexColor'] ?? '#81C784', 
          };
        }).toList();
        setState(() {
          _allTasksForSelectedDay = parsedTasks;
          _onSearchChanged(); 
          _isLoadingTasks = false;
        });
      }
    } catch (e) {
      setState(() {
        _allTasksForSelectedDay = [];
        _filteredTasks = [];
        _isLoadingTasks = false;
      });
    }
  }

  void _showCustomNotification(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFF1A1A1A),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(6),
          side: const BorderSide(color: Color(0xFFE57373), width: 1),
        ),
        content: Text(
          message.toUpperCase(),
          style: const TextStyle(
            color: Color(0xFFE57373),
            fontSize: 11,
            fontWeight: FontWeight.w700,
            fontFamily: 'Courier',
          ),
        ),
      ),
    );
  }

  void _createNewTaskOnBackend(String name, String description, int priorityId, DateTime date) async {
    try {
      final String formattedDate = "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
      final response = await http.post(
        Uri.parse('http://localhost:3145/tasks'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "Name": name,
          "Description": description,
          "PriorityId": priorityId,
          "DayOrder": _allTasksForSelectedDay.length + 1,
          "Date": formattedDate,
          "IsCompleted": false
        }),
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        _fetchTasksForDay(_selectedDate);
        _fetchWeekStatus(); 
      } else {
        _showCustomNotification("Server error: ${response.statusCode}");
      }
    } catch (e) {
      _showCustomNotification("Network error. Check connection.");
    }
  }

  void _fetchWeekStatus() async {
    setState(() {
      _isLoadingWeek = true;
    });
    try {
      final String formattedMonday = DateFormat('yyyy-MM-dd').format(_currentMonday);
      final url = Uri.parse('http://localhost:3145/tasks/on_week_status?startWeekDay=$formattedMonday');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        final List<String> labels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
        final DateTime today = DateTime.now();
        List<Map<String, dynamic>> parsedDays = [];

        for (int i = 0; i < data.length; i++) {
          final dayData = data[i];
          final DateTime parsedDate = DateTime.tryParse(dayData['date'] ?? '') ?? DateTime.now();
          
          final bool isToday = parsedDate.year == today.year &&
              parsedDate.month == today.month &&
              parsedDate.day == today.day;
          parsedDays.add({
            'date': parsedDate,
            'day': DateFormat('dd').format(parsedDate),
            'label': labels[i],
            'isToday': isToday,
            'completed': dayData['completedTasks'] as int,
            'uncompleted': dayData['unCompletedTasks'] as int,
          });
        }

        setState(() {
          _weekDays = parsedDays;
          _isLoadingWeek = false;
        });
      }
    } catch (e) {
      _buildFallbackWeek();
    }
  }

  void _updateCalendarDots() {
    int completedCount = _allTasksForSelectedDay.where((t) => t['isCompleted'] == true).length;
    int uncompletedCount = _allTasksForSelectedDay.where((t) => t['isCompleted'] == false).length;

    setState(() {
      _weekDays = _weekDays.map((dayData) {
        final DateTime dayDate = dayData['date'];
        final bool isSelected = dayDate.year == _selectedDate.year &&
            dayDate.month == _selectedDate.month &&
            dayDate.day == _selectedDate.day;

        if (isSelected) {
          return {
            ...dayData,
            'completed': completedCount,
            'uncompleted': uncompletedCount,
          };
        }
        return dayData;
      }).toList();
    });
  }

  void _buildFallbackWeek() {
    final List<String> labels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final DateTime today = DateTime.now();
    
    setState(() {
      _weekDays = List.generate(7, (i) {
        final day = _currentMonday.add(Duration(days: i));
        final bool isToday = day.year == today.year && day.month == today.month && day.day == today.day;
        return {
          'date': day,
          'day': DateFormat('dd').format(day),
          'label': labels[i],
          'isToday': isToday,
          'completed': 0,
          'uncompleted': 0,
        };
      });
      _isLoadingWeek = false;
    });
  }

  void _changeWeek(int weeksToAdd) {
    setState(() {
      _currentMonday = _currentMonday.add(Duration(days: weeksToAdd * 7));
      if (weeksToAdd > 0) {
        _selectedDate = _currentMonday;
      } else {
        _selectedDate = _currentMonday.add(const Duration(days: 6));
      }
    });
    _fetchWeekStatus();
    _fetchTasksForDay(_selectedDate); 
  }

  void _fetchTodayQuote() async {
    try {
      final url = Uri.parse('http://localhost:3145/quotes/today');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        setState(() {
          _quoteText = data['text'] ?? "";
          _quoteAuthor = data['author'] ?? "";
        });
      } else {
        setState(() {
          _quoteText = "ERROR: ${response.statusCode}";
        });
      }
    } catch (e) {
      setState(() {
        _quoteText = "CANNOT CONNECT TO SERVER";
      });
    }
  }

  void _toggleTaskStatusOnBackend(int taskId) async {
    try {
      final response = await http.patch(
        Uri.parse('http://localhost:3145/tasks/$taskId/complete_status_toggle'),
      );
      if (response.statusCode != 204) {
        print('Ошибка обновления статуса задачи: ${response.statusCode}');
      }
    } catch (e) {
      print('Сетевая ошибка при PATCH запросе: $e');
    }
  }

  void _updateTaskOnBackend(int taskId, String name, String description, int priorityId, DateTime date, bool isCompleted, int dayOrder) async {
    try {
      final String formattedDate = "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
      final response = await http.put(
        Uri.parse('http://localhost:3145/tasks/$taskId'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "Name": name,
          "IsCompleted": isCompleted,
          "Description": description,
          "PriorityId": priorityId,
          "DayOrder": dayOrder,
          "Date": formattedDate,
        }),
      );
      if (response.statusCode == 200 || response.statusCode == 204) {
        _fetchTasksForDay(_selectedDate);
        _fetchWeekStatus();
      } else {
        print("Ошибка бэкенда: ${response.statusCode}");
      }
    } catch (e) {
      print("Сетевая ошибка обновления: $e");
    }
  }

  void _deleteTaskFromBackend(int taskId) async {
    try {
      final response = await http.delete(
        Uri.parse('http://localhost:3145/tasks/$taskId'),
      );
      if (response.statusCode == 200 || response.statusCode == 204) {
        _fetchTasksForDay(_selectedDate);
        _fetchWeekStatus();
      }
    } catch (e) {
      print("Ошибка удаления: $e");
    }
  }

  void _confirmDelete(int taskId) {
    if (!_showDeleteConfirmation) {
      _deleteTaskFromBackend(taskId);
      return;
    }

    bool localDontAskAgain = false;

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss',
      barrierColor: Colors.black.withOpacity(0.7),
      transitionDuration: const Duration(milliseconds: 150),
      pageBuilder: (context, animation, secondaryAnimation) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Center(
              child: Material(
                color: Colors.transparent,
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
                  child: Container(
                    width: MediaQuery.of(context).size.width * 0.8,
                    constraints: const BoxConstraints(maxWidth: 320),
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F0F0F),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFF1A1A1A)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          "DELETE TASK",
                          style: TextStyle(
                            color: Color(0xFFE57373),
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.5,
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          "Are you sure you want to permanently delete this task?",
                          style: TextStyle(color: Color(0xFF8C8C8C), fontSize: 13),
                        ),
                        const SizedBox(height: 16),
                        GestureDetector(
                          onTap: () {
                            setModalState(() {
                              localDontAskAgain = !localDontAskAgain;
                            });
                          },
                          child: Row(
                            children: [
                              Container(
                                width: 16,
                                height: 16,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF141414),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(
                                    color: localDontAskAgain ? const Color(0xFF81C784) : const Color(0xFF1A1A1A),
                                  ),
                                ),
                                child: localDontAskAgain
                                    ? const Icon(Icons.check, color: Color(0xFF81C784), size: 12)
                                    : null,
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                "DON'T ASK AGAIN",
                                style: TextStyle(color: Color(0xFF4D4D4D), fontSize: 10, fontWeight: FontWeight.w700),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text("CANCEL", style: TextStyle(color: Color(0xFF4D4D4D), fontSize: 11, fontWeight: FontWeight.w700)),
                            ),
                            const SizedBox(width: 12),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF1A1A1A),
                                elevation: 0,
                                side: const BorderSide(color: Color(0xFF1A1A1A)),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                              ),
                              onPressed: () {
                                if (localDontAskAgain) {
                                  setState(() {
                                    _showDeleteConfirmation = false;
                                  });
                                }
                                _deleteTaskFromBackend(taskId);
                                Navigator.pop(context);
                              },
                              child: const Text("DELETE", style: TextStyle(color: Color(0xFFE57373), fontSize: 11, fontWeight: FontWeight.w700)),
                            ),
                          ],
                        )
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showTaskDialog({Map<String, dynamic>? task}) {
    final bool isEditMode = task != null;

    final TextEditingController nameController = TextEditingController(
      text: isEditMode ? task['name'] : '',
    );
    final TextEditingController descController = TextEditingController(
      text: isEditMode ? task['description'] : '',
    );

    int selectedPriorityId = 1; // LOW по умолчанию
    if (isEditMode) {
      final String priority = (task['priorityName'] ?? 'LOW').toString().toUpperCase();
      if (priority == 'MEDIUM') selectedPriorityId = 2;
      if (priority == 'HIGH') selectedPriorityId = 3;
    }

    DateTime selectedTaskDate = _selectedDate;
    if (isEditMode && task['date'] != null) {
      selectedTaskDate = DateTime.tryParse(task['date']) ?? _selectedDate;
    }

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss',
      barrierColor: Colors.black.withValues(alpha: 0.6),
      transitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (context, animation, secondaryAnimation) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            nameController.addListener(() {
              if (context.mounted) setModalState(() {});
            });

            final bool isFormValid = nameController.text.trim().isNotEmpty;

            return Center(
              child: SingleChildScrollView(
                child: Material(
                  color: Colors.transparent,
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                    child: Container(
                      width: MediaQuery.of(context).size.width * 0.9,
                      constraints: const BoxConstraints(maxWidth: 400),
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F0F0F),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFF1A1A1A)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                isEditMode ? "EDIT TASK" : "NEW TASK",
                                style: const TextStyle(
                                  color: Color(0xFF4D4D4D),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1.5,
                                ),
                              ),
                              GestureDetector(
                                onTap: () => Navigator.pop(context),
                                child: const Icon(Icons.close, color: Color(0xFF4D4D4D), size: 16),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),

                          // TASK NAME ПОЛЕ С ПОСТОЯННОЙ ЗЕЛЕНОЙ ОБВОДКОЙ
                          const Text(
                            "TASK NAME *",
                            style: TextStyle(color: Color(0xFF333333), fontSize: 10, fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 6),
                          Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFF141414),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: const Color(0xFF81C784), width: 1.0),
                            ),
                            child: TextField(
                              controller: nameController,
                              style: const TextStyle(color: Colors.white, fontSize: 13),
                              cursorColor: const Color(0xFFFFB74D),
                              decoration: const InputDecoration(
                                hintText: 'What needs to be done?',
                                hintStyle: TextStyle(color: Color(0xFF333333), fontSize: 13),
                                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                border: InputBorder.none,
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),

                          // DESCRIPTION ПОЛЕ
                          const Text(
                            "DESCRIPTION",
                            style: TextStyle(color: Color(0xFF333333), fontSize: 10, fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 6),
                          Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFF141414),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: const Color(0xFF1A1A1A)),
                            ),
                            child: TextField(
                              controller: descController,
                              maxLines: 3,
                              style: const TextStyle(color: Colors.white, fontSize: 13),
                              cursorColor: const Color(0xFFFFB74D),
                              decoration: const InputDecoration(
                                hintText: 'Optional details...',
                                hintStyle: TextStyle(color: Color(0xFF333333), fontSize: 13),
                                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                border: InputBorder.none,
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),

                          // PRIORITY КНОПКИ
                          const Text(
                            "PRIORITY",
                            style: TextStyle(color: Color(0xFF333333), fontSize: 10, fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              _buildPriorityButton(1, "LOW", const Color(0xFF81C784), selectedPriorityId, () => setModalState(() => selectedPriorityId = 1)),
                              const SizedBox(width: 8),
                              _buildPriorityButton(2, "MEDIUM", const Color(0xFFFFB74D), selectedPriorityId, () => setModalState(() => selectedPriorityId = 2)),
                              const SizedBox(width: 8),
                              _buildPriorityButton(3, "HIGH", const Color(0xFFE57373), selectedPriorityId, () => setModalState(() => selectedPriorityId = 3)),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // DATE СЕЛЕКТОР
                          const Text(
                            "DATE",
                            style: TextStyle(color: Color(0xFF333333), fontSize: 10, fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 6),
                          GestureDetector(
                            onTap: () async {
                              final DateTime? picked = await showDatePicker(
                                context: context,
                                initialDate: selectedTaskDate,
                                firstDate: DateTime(2025),
                                lastDate: DateTime(2030),
                              );
                              if (picked != null) {
                                setModalState(() => selectedTaskDate = picked);
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                              decoration: BoxDecoration(
                                color: const Color(0xFF141414),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: const Color(0xFF1A1A1A)),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    "${selectedTaskDate.day.toString().padLeft(2, '0')}.${selectedTaskDate.month.toString().padLeft(2, '0')}.${selectedTaskDate.year}",
                                    style: const TextStyle(color: Colors.white, fontSize: 13, fontFamily: 'Courier'),
                                  ),
                                  const Icon(Icons.calendar_today_outlined, color: Color(0xFF4D4D4D), size: 16),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),

                          // УПРАВЛЯЮЩИЕ КНОПКИ С ДИНАМИЧЕСКИМ ЦВЕТОМ
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  style: OutlinedButton.styleFrom(
                                    backgroundColor: Colors.transparent,
                                    side: const BorderSide(color: Color(0xFF1A1A1A)),
                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                  ),
                                  onPressed: () => Navigator.pop(context),
                                  child: const Text("CANCEL", style: TextStyle(color: Color(0xFF4D4D4D), fontSize: 11, fontWeight: FontWeight.w700)),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: isFormValid ? const Color(0xFF81C784) : const Color(0xFF1A1A1A),
                                    elevation: 0,
                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(6),
                                      side: const BorderSide(color: Color(0xFF1A1A1A)),
                                    ),
                                  ),
                                  onPressed: isFormValid ? () {
                                    if (isEditMode) {
                                      _updateTaskOnBackend(
                                        task['id'],
                                        nameController.text.trim(),
                                        descController.text.trim(),
                                        selectedPriorityId,
                                        selectedTaskDate,
                                        task['isCompleted'] ?? false, // Сохраняем текущий статус выполнения
                                        task['dayOrder'] ?? 1,        // Сохраняем текущий порядок в дне
                                      );
                                    } else {
                                      _createNewTaskOnBackend(
                                        nameController.text.trim(),
                                        descController.text.trim(),
                                        selectedPriorityId,
                                        selectedTaskDate,
                                      );
                                    }
                                    Navigator.pop(context);
                                  } : null,
                                  child: Text(
                                    isEditMode ? "SAVE CHANGES" : "ADD TASK", 
                                    style: TextStyle(
                                      color: isFormValid ? Colors.black : const Color(0xFF4D4D4D), 
                                      fontSize: 11, 
                                      fontWeight: FontWeight.w700
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildPriorityButton(int id, String label, Color activeColor, int currentSelected, VoidCallback onTap) {
    final bool isSelected = id == currentSelected;
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFF141414),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: isSelected ? activeColor : const Color(0xFF1A1A1A),
              width: isSelected ? 1.5 : 1.0,
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: isSelected ? activeColor : const Color(0xFF333333),
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final DateTime now = DateTime.now();
    final String formattedYear = DateFormat('dd.MM.yyyy').format(now);
    final DateTime sunday = _currentMonday.add(const Duration(days: 6));

    final String startDay = DateFormat('dd').format(_currentMonday);
    final String endDay = DateFormat('dd').format(sunday);
    final String monthYear = DateFormat('MMM yyyy', 'en_US').format(sunday).toUpperCase();
    final String weekRange = "$startDay-$endDay $monthYear";

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.only(left: 10.0, top: 10.0, right: 10.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                formattedYear,
                style: const TextStyle(
                  color: Color(0xFF4D4D4D),
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                '"$_quoteText"',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
              if (_quoteAuthor.isNotEmpty) ...[
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    _quoteAuthor.toUpperCase(),
                    style: const TextStyle(
                      color: Color(0xFF888888),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
              ],
              const Divider(color: Color(0xFF4D4D4D), thickness: 1, height: 20),
              const SizedBox(height: 14), 
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    weekRange,
                    style: const TextStyle(
                      color: Color(0xFF4D4D4D),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 1.8,
                ),
                  ),
                  Row(
                    children: [
                      _buildArrowButton(Icons.chevron_left, () => _changeWeek(-1)),
                      const SizedBox(width: 8),
                      _buildArrowButton(Icons.chevron_right, () => _changeWeek(1)),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 24),

              _isLoadingWeek
                  ? const Center(
                      child: SizedBox(
                        width: 20, height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF4CAF50)),
                      ),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: _weekDays.map((data) {
                        final DateTime dayDate = data['date'];
                        final bool isSelected = dayDate.year == _selectedDate.year &&
                            dayDate.month == _selectedDate.month &&
                            dayDate.day == _selectedDate.day;

                        return _buildCalendarDay(
                          day: data['day'],
                          label: data['label'],
                          isToday: data['isToday'],
                          isSelected: isSelected,
                          completedCount: data['completed'] ?? 0,
                          uncompletedCount: data['uncompleted'] ?? 0,
                          onTap: () {
                            setState(() {
                              _selectedDate = dayDate;
                            });
                            _fetchTasksForDay(_selectedDate);
                          },
                        );
                      }).toList(),
                    ),
              const SizedBox(height: 28),

              Builder(
                builder: (context) {
                  final DateTime today = DateTime.now();
                  final bool isSelectedToday = today.year == _selectedDate.year &&
                      today.month == _selectedDate.month &&
                      today.day == _selectedDate.day;

                  final String prefix = isSelectedToday ? "TODAY – " : "";
                  final String dateString = DateFormat('EEE, d MMM yyyy', 'en_US').format(_selectedDate).toUpperCase();
                  
                  int totalTasks = _allTasksForSelectedDay.length;
                  int completedTasks = _allTasksForSelectedDay.where((t) => t['isCompleted'] == true).length;
                  double progressFraction = totalTasks > 0 ? completedTasks / totalTasks : 0.0;

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "$prefix$dateString",
                            style: const TextStyle(
                              color: Color(0xFF4D4D4D),
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              letterSpacing: 1.5,
                            ),
                          ),
                          Text(
                            "$completedTasks/$totalTasks",
                            style: const TextStyle(
                              color: Color(0xFF4D4D4D),
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      TweenAnimationBuilder<double>(
                        tween: Tween<double>(begin: 0.0, end: progressFraction),
                        duration: const Duration(milliseconds: 350),
                        curve: Curves.easeInOutCubic,
                        builder: (context, value, child) {
                          return LinearProgressIndicator(
                            value: value,
                            backgroundColor: const Color(0xFF141414),
                            color: const Color(0xFF4CAF50),
                            minHeight: 2,
                          );
                        },
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 16),

              Container(
                height: 38,
                decoration: BoxDecoration(
                  color: const Color(0xFF111111),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFF1A1A1A)),
                ),
                child: TextField(
                  controller: _searchController,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  cursorColor: const Color(0xFF4CAF50),
                  decoration: const InputDecoration(
                    hintText: 'Search tasks...',
                    hintStyle: TextStyle(color: Color(0xFF4D4D4D), fontSize: 13),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    border: InputBorder.none,
                  ),
                ),
              ),
              const SizedBox(height: 20),

              Expanded(
                child: _filteredTasks.isEmpty
                    ? const Center(
                        child: Text(
                          'No tasks found',
                          style: TextStyle(color: Color(0xFF4D4D4D), fontSize: 13),
                        ),
                      )
                    : Builder(
                        builder: (context) {
                          final activeTasks = _filteredTasks.where((t) => t['isCompleted'] == false).toList();
                          final completedTasks = _filteredTasks.where((t) => t['isCompleted'] == true).toList();

                          return ListView(
                            padding: const EdgeInsets.only(bottom: 20),
                            children: [
                              ...activeTasks.map((task) => _buildTaskTile(task)),
                              if (completedTasks.isNotEmpty) ...[
                                const SizedBox(height: 16),
                                InkWell(
                                  onTap: () {
                                    setState(() {
                                      _isCompletedSectionExpanded = !_isCompletedSectionExpanded;
                                    });
                                  },
                                  splashColor: Colors.transparent,
                                  highlightColor: Colors.transparent,
                                  hoverColor: Colors.transparent,
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          "COMPLETED (${completedTasks.length})",
                                          style: const TextStyle(
                                            color: Color(0xFF4D4D4D),
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                            letterSpacing: 1.5,
                                          ),
                                        ),
                                        Icon(
                                          _isCompletedSectionExpanded ? Icons.expand_less : Icons.expand_more,
                                          color: const Color(0xFF4D4D4D),
                                          size: 18,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                if (_isCompletedSectionExpanded)
                                  ...completedTasks.map((task) => _buildTaskTile(task)),
                              ],
                            ],
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showTaskDialog(),
        backgroundColor: const Color(0xFF141414),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: Color(0xFF1A1A1A)),
        ),
        child: const Icon(
          Icons.add,
          color: Colors.white,
          size: 20,
        ),
      ),
    );
  }

  Widget _buildArrowButton(IconData icon, VoidCallback onTap) {
    return Container(
      width: 32, height: 32,
      decoration: BoxDecoration(
        color: const Color(0xFF0D0D0D),
        border: Border.all(color: const Color(0xFF1A1A1A)),
        borderRadius: BorderRadius.circular(6),
      ),
      child: IconButton(
        padding: EdgeInsets.zero,
        icon: Icon(icon, color: const Color(0xFF666666), size: 18),
        onPressed: onTap,
      ),
    );
  }

  Widget _buildCalendarDay({
    required String day,
    required String label,
    required bool isToday,
    required bool isSelected,
    required int completedCount,
    required int uncompletedCount,
    required VoidCallback onTap,
  }) {
    final Color labelColor = (isSelected || isToday) ? const Color(0xFF4CAF50) : const Color(0xFF4D4D4D);
    const Color completedDotColor = Color(0xFF4CAF50);
    const Color uncompletedDotColor = Color(0xFF333333);

    BoxDecoration circleDecoration;
    Color textColor;

    if (isSelected) {
      circleDecoration = const BoxDecoration(color: Color(0xFF4CAF50), shape: BoxShape.circle);
      textColor = Colors.black;
    } else if (isToday) {
      circleDecoration = BoxDecoration(
        color: Colors.transparent,
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xFF4CAF50), width: 1.5),
      );
      textColor = Colors.white;
    } else {
      circleDecoration = const BoxDecoration(color: Colors.transparent, shape: BoxShape.circle);
      textColor = Colors.white;
    }

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(color: labelColor, fontSize: 11, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 12),
          Container(
            width: 36, height: 36,
            alignment: Alignment.center,
            decoration: circleDecoration,
            child: Text(
              day,
              style: TextStyle(color: textColor, fontSize: 14, fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(height: 6),
          SizedBox(
            width: 20,
            child: Wrap(
              alignment: WrapAlignment.center,
              runAlignment: WrapAlignment.start,
              spacing: 2.0,
              runSpacing: 2.0,
              children: [
                ...List.generate(completedCount, (index) => Container(
                  width: 4, height: 4,
                  decoration: const BoxDecoration(color: completedDotColor, shape: BoxShape.circle),
                )),
                ...List.generate(uncompletedCount, (index) => Container(
                  width: 4, height: 4,
                  decoration: const BoxDecoration(color: uncompletedDotColor, shape: BoxShape.circle),
                )),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTaskTile(Map<String, dynamic> task) {
    final int taskId = task['id'];
    final bool isCompleted = task['isCompleted'] ?? false;
    final String description = task['description'] ?? '';

    final String priorityText = (task['priorityName'] as String).toUpperCase();
    final Color priorityColor = parseHexColor(task['priorityColor'] ?? '#81C784');
    final Color currentIndicatorColor = isCompleted ? priorityColor.withValues(alpha: 0.3) : priorityColor;

    return GestureDetector(
      onTap: () => _showTaskDialog(task: task),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF0D0D0D),
          border: Border.all(color: const Color(0xFF141414)),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: currentIndicatorColor,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 12),

            GestureDetector(
              onTap: () {
                setState(() {
                  task['isCompleted'] = !isCompleted;
                });
                _updateCalendarDots();
                _toggleTaskStatusOnBackend(task['id']);
              },
              child: Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  shape: BoxShape.rectangle,
                  borderRadius: BorderRadius.circular(4), 
                  border: Border.all(
                    color: isCompleted ? const Color(0xFF4CAF50) : const Color(0xFF333333),
                    width: 1.5,
                  ),
                  color: isCompleted ? const Color(0xFF4CAF50) : Colors.transparent,
                ),
                child: isCompleted
                    ? const Icon(Icons.check, size: 12, color: Colors.black)
                    : null,
              ),
            ),
            const SizedBox(width: 12),
            
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    task['name'] ?? '',
                    style: TextStyle(
                      color: isCompleted ? const Color(0xFF333333) : Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      decoration: isCompleted ? TextDecoration.lineThrough : TextDecoration.none,
                    ),
                  ),
                  if (description.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: TextStyle(
                        color: isCompleted ? const Color(0xFF222222) : const Color(0xFF4D4D4D),
                        fontSize: 11,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 12),

            // ИКОНКА КОРЗИНЫ НА КАРТОЧКЕ ЗАДАЧИ С КЛИКОМ НА ПОДТВЕРЖДЕНИЕ
            // GestureDetector(
            //   onTap: () => _confirmDelete(taskId),
            //   child: const Padding(
            //     padding: EdgeInsets.symmetric(horizontal: 8.0),
            //     child: Icon(
            //       Icons.delete_outline_rounded,
            //       color: Color(0xFF333333),
            //       size: 18,
            //     ),
            //   ),
            // ),
            const SizedBox(width: 4),

            Text(
              priorityText,
              style: TextStyle(
                color: currentIndicatorColor,
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.0,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
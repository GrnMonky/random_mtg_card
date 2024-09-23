import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:wakelock_plus/wakelock_plus.dart'; // Import wakelock_plus
import 'dart:convert';
import 'dart:async';

class MTGCardApp extends StatelessWidget {
  const MTGCardApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MTG Card Viewer',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        secondaryHeaderColor: Colors.red,
      ),
      home: const RandomCardPage(),
    );
  }
}

class RandomCardPage extends StatefulWidget {
  const RandomCardPage({super.key});

  @override
  _RandomCardPageState createState() => _RandomCardPageState();
}

class _RandomCardPageState extends State<RandomCardPage>
    with WidgetsBindingObserver {
  String cardImageUrl = '';
  String cardType = '';
  bool isPlaying = true;
  int intervalDuration = 20; // Initial interval duration in seconds
  Timer? timer;
  Color backgroundColor = Colors.black; // Initial background color

  // List to store card history
  List<String> cardHistory = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this); // Add observer for app lifecycle
    fetchRandomCard();
    startTimer();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this); // Remove observer when done
    timer?.cancel();
    WakelockPlus.disable(); // Disable wakelock when the screen is disposed
    super.dispose();
  }

  // Detect app lifecycle changes
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      // App is in the background or detached, stop the timer
      stopTimer();
    } else if (state == AppLifecycleState.resumed) {
      // App is back to the foreground, restart the timer
      if (isPlaying) {
        startTimer();
      }
    }
  }

  // Function to fetch a random card
  Future<void> fetchRandomCard() async {
    try {
      final response = await http
          .get(Uri.parse('https://api.scryfall.com/cards/random?lang=en'));
      if (response.statusCode == 200) {
        final cardData = json.decode(response.body);
        setState(() {
          // Add the current card to history before changing it
          if (cardImageUrl.isNotEmpty) {
            cardHistory.add(cardImageUrl);
          }
          cardImageUrl = cardData['image_uris']['png'];
          List<String> manaColors =
              List<String>.from(cardData['colors']); // Get card mana type

          var color = getBackgroundColorFromManaType(manaColors);

          // Set background color based on mana type
          backgroundColor = (color == Colors.black || color == Colors.white)
              ? color
              : HSLColor.fromColor(color).withLightness(0.1).toColor();
        });
      } else {
        if (kDebugMode) {
          print('Failed to load card');
        }
      }
    } catch (error) {
      if (kDebugMode) {
        print('Error fetching card: $error');
      }
    }
  }

  // Function to map mana types to background colors
  Color getBackgroundColorFromManaType(List<String> manaColors) {
    var first = manaColors.firstOrNull ?? "E";
    switch (first) {
      case 'W':
        return Colors.white;
      case 'U':
        return Colors.blue;
      case 'B':
        return Colors.grey;
      case 'R':
        return Colors.red;
      case 'G':
        return Colors.green;
      case 'E':
        return Colors.purple; // Colorless cards
      default:
        return Colors.black; // For multicolored or any other cards
    }
  }

  // Function to go back to the previous card
  void goBackToPreviousCard() {
    if (cardHistory.isNotEmpty) {
      setState(() {
        // Set the current card to the last card in history
        cardImageUrl = cardHistory.removeLast();
      });
      startTimer(); // Reset the timer when "Previous" is pressed
    }
  }

  // Function to start the timer for fetching cards
  void startTimer() {
    timer?.cancel(); // Cancel any existing timer
    timer = Timer.periodic(Duration(seconds: intervalDuration), (timer) {
      fetchRandomCard();
    });
    WakelockPlus
        .enable(); // Enable wakelock to prevent the screen from sleeping
    setState(() {
      isPlaying = true;
    });
  }

  // Function to stop the timer
  void stopTimer() {
    timer?.cancel();
    WakelockPlus.disable(); // Disable wakelock to allow the screen to sleep
    setState(() {
      isPlaying = false;
    });
  }

  // Toggle between play and pause
  void togglePlayPause() {
    if (isPlaying) {
      stopTimer();
    } else {
      startTimer();
    }
  }

  // Handle slider value change
  void handleSliderChange(double newValue) {
    setState(() {
      intervalDuration = newValue.toInt();
    });
    if (isPlaying) {
      startTimer(); // Restart timer with new duration
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Dynamically set background color based on mana type
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment
              .spaceBetween, // Space between top and bottom elements
          children: [
            // Top section: Card image
            cardImageUrl.isNotEmpty
                ? Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Image.network(
                        cardImageUrl,
                        fit: BoxFit
                            .contain, // Resizes the image to avoid getting cut off
                      ),
                    ),
                  )
                : const Text(
                    'Loading...',
                    style: TextStyle(
                        color: Colors.white), // Text color for loading message
                  ),
            // Bottom section with background color behind text, buttons, and slider
            Container(
              color: Colors.black54, // Background color for the bottom section
              padding: const EdgeInsets.all(
                  16.0), // Padding around the text, buttons, and slider
              child: Column(
                children: [
                  // Slider to change speed
                  Text(
                    'Change speed (seconds): $intervalDuration',
                    style: const TextStyle(
                        color: Colors.white), // Text color for slider label
                  ),
                  Slider(
                    value: intervalDuration.toDouble(),
                    min: 10,
                    max: 120,
                    divisions: 22,
                    label: '$intervalDuration seconds',
                    onChanged: handleSliderChange,
                    activeColor: Colors.white, // Slider color for visibility
                    inactiveColor: Colors.grey,
                  ),

                  // Buttons for previous, play/pause, and next
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Conditionally show "Previous" button if there's history
                      if (cardHistory.isNotEmpty)
                        ElevatedButton(
                          onPressed: goBackToPreviousCard,
                          child: const Text('Previous'),
                        ),
                      const SizedBox(width: 10),
                      ElevatedButton(
                        onPressed: togglePlayPause,
                        child: Text(isPlaying ? 'Pause' : 'Play'),
                      ),
                      const SizedBox(width: 10),
                      ElevatedButton(
                        onPressed: () {
                          fetchRandomCard();
                          startTimer(); // Reset the timer when "Next" is pressed
                        },
                        child: const Text('Next'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

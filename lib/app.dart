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
    return const MaterialApp(
      title: 'MTG Card Viewer',
      home: RandomCardPage(),
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
  String nextCardImageUrl = ''; // URL for preloading the next card image
  bool isPlaying = true;
  int intervalDuration = 30; // Initial interval duration in seconds
  Timer? timer;
  Color backgroundColor = Colors.black; // Initial background color

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this); // Add observer for app lifecycle
    fetchRandomCard(); // Load the initial card
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
      stopTimer();
    } else if (state == AppLifecycleState.resumed) {
      if (isPlaying) {
        startTimer();
      }
    }
  }

  // Function to fetch a random card
  Future<void> fetchRandomCard({bool preloadNext = false}) async {
    try {
      final response = await http
          .get(Uri.parse('https://api.scryfall.com/cards/random?lang=en'));
      if (response.statusCode == 200) {
        final cardData = json.decode(response.body);
        String newCardImageUrl = cardData['image_uris']['png'];

        if (preloadNext) {
          nextCardImageUrl = newCardImageUrl; // Preload the next card
          precacheImage(
              NetworkImage(nextCardImageUrl), context); // Preload image
        } else {
          setState(() {
            cardImageUrl = newCardImageUrl; // Display the current card
          });
          // After showing the current card, preload the next card
          fetchRandomCard(preloadNext: true);
        }
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

  // Function to start the timer for fetching cards
  void startTimer() {
    timer?.cancel(); // Cancel any existing timer
    timer = Timer.periodic(Duration(seconds: intervalDuration), (timer) {
      setState(() {
        cardImageUrl = nextCardImageUrl; // Show the preloaded next card
      });
      fetchRandomCard(preloadNext: true); // Preload the next card
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
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            cardImageUrl.isNotEmpty
                ? Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Image.network(
                        cardImageUrl,
                        fit: BoxFit.contain,
                      ),
                    ),
                  )
                : const Text(
                    'Loading...',
                    style: TextStyle(color: Colors.white),
                  ),
            Container(
              color: Colors.black54,
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Text(
                    'Change speed (seconds): $intervalDuration',
                    style: const TextStyle(color: Colors.white),
                  ),
                  Slider(
                    value: intervalDuration.toDouble(),
                    min: 10,
                    max: 120,
                    divisions: 22,
                    label: '$intervalDuration',
                    onChanged: handleSliderChange,
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ElevatedButton(
                        onPressed: togglePlayPause,
                        child: Text(isPlaying ? 'Pause' : 'Play'),
                      ),
                      const SizedBox(width: 10),
                      ElevatedButton(
                        onPressed: () {
                          setState(() {
                            cardImageUrl = nextCardImageUrl; // Show next card
                          });
                          fetchRandomCard(preloadNext: true); // Preload another
                          startTimer();
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

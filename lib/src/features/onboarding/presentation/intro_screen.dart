import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/mc.dart';
import '../../../core/widgets/map_background.dart';

class IntroScreen extends StatefulWidget {
  const IntroScreen({super.key});

  @override
  State<IntroScreen> createState() => _IntroScreenState();
}

class _IntroScreenState extends State<IntroScreen> {
  final PageController _controller = PageController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _next() {
    _controller.nextPage(
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Brand.bg,
      body: SafeArea(
        child: PageView(
          controller: _controller,
          children: [
            _IntroSlide(
              dot: 0,
              title: 'Rides at your\nfingertips',
              body:
                  "Book a MAP CARS ride in seconds — set your destination and we'll match you with a nearby driver.",
              art: const _MapArt(),
              onNext: _next,
            ),
            _IntroSlide(
              dot: 1,
              title: 'Track every\nstep, live',
              body:
                  'Watch your driver arrive in real time, see their car and plate, and share your trip with friends for peace of mind.',
              art: const _TrackingArt(),
              onNext: _next,
            ),
            _IntroSlide(
              dot: 2,
              last: true,
              title: 'Pay your\nway, cashless',
              body:
                  'Add a card once and ride. Get a clear fare upfront, automatic receipts, and tip your driver in a tap.',
              art: const _CardArt(),
              onNext: _next,
            ),
          ],
        ),
      ),
    );
  }
}

class _IntroSlide extends StatelessWidget {
  const _IntroSlide({
    required this.dot,
    required this.title,
    required this.body,
    required this.art,
    required this.onNext,
    this.last = false,
  });

  final int dot;
  final String title;
  final String body;
  final Widget art;
  final VoidCallback onNext;
  final bool last;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 12, 22, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Image.asset('assets/images/logo-full.png', height: 28),
              if (!last)
                GestureDetector(
                  onTap: () => context.go('/phone'),
                  child: Text('Skip', style: tw(FontWeight.w800, 14, Brand.sub)),
                ),
            ],
          ),
          const SizedBox(height: 18),
          ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: Container(
              height: 268,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: Brand.line),
              ),
              clipBehavior: Clip.antiAlias,
              child: art,
            ),
          ),
          const SizedBox(height: 26),
          McTitle(title, size: 30),
          const SizedBox(height: 12),
          Text(body, style: tw(FontWeight.w600, 15, Brand.sub)),
          const Spacer(),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(3, (i) {
              final active = i == dot;
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 3.5),
                width: active ? 22 : 7,
                height: 7,
                decoration: BoxDecoration(
                  color: active ? Brand.blue : Brand.line,
                  borderRadius: BorderRadius.circular(99),
                ),
              );
            }),
          ),
          const SizedBox(height: 20),
          if (last)
            McButton('Get started',
                icon: 'bolt',
                kind: BtnKind.grad,
                onTap: () => context.go('/phone'))
          else
            McButton('Next', icon: 'chevR', onTap: onNext),
          const SizedBox(height: 16),
          Center(
            child: GestureDetector(
              onTap: () => context.go('/phone'),
              child: Text.rich(
                TextSpan(
                  text: 'Already have an account? ',
                  style: tw(FontWeight.w700, 14, Brand.sub),
                  children: [
                    TextSpan(
                      text: 'Log in',
                      style: tw(FontWeight.w700, 14, Brand.blue),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MapArt extends StatelessWidget {
  const _MapArt();

  @override
  Widget build(BuildContext context) {
    return const MapBackground(
      route: true,
      markers: [
        MapMarker(0.62, 0.46, MapPin(dest: true)),
        MapMarker(0.30, 0.74, MapPin(dest: false)),
      ],
    );
  }
}

class _TrackingArt extends StatelessWidget {
  const _TrackingArt();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const Positioned.fill(
          child: MapBackground(
            route: true,
            markers: [
              MapMarker(0.28, 0.76, MapPin(dest: false)),
              MapMarker(0.54, 0.48, CarMark()),
            ],
          ),
        ),
        Positioned(
          top: 14,
          left: 14,
          right: 14,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
            decoration: BoxDecoration(
              color: Brand.ink,
              borderRadius: BorderRadius.circular(13),
            ),
            child: Row(
              children: [
                const Ico('car', size: 18, color: Brand.lime),
                const SizedBox(width: 10),
                Text('Arriving in 3 min',
                    style: tw(FontWeight.w900, 13, Colors.white)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _CardArt extends StatelessWidget {
  const _CardArt();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          transform: GradientRotation(150 * 3.1415926535 / 180),
          colors: [Color(0xFFEAF6FB), Color(0xFFECF8E7)],
        ),
      ),
      child: Center(
        child: SizedBox(
          width: 220,
          height: 150,
          child: Stack(
            children: [
              // back card
              Positioned(
                top: 18,
                left: 30,
                child: Transform.rotate(
                  angle: -8 * 3.1415926535 / 180,
                  child: Container(
                    width: 180,
                    height: 110,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Brand.line),
                      boxShadow: const [
                        BoxShadow(
                            color: Color(0x1F283443),
                            blurRadius: 24,
                            offset: Offset(0, 10)),
                      ],
                    ),
                  ),
                ),
              ),
              // front gradient card
              Positioned(
                top: 6,
                left: 18,
                child: Container(
                  width: 184,
                  height: 114,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Brand.blue,
                        Color(0xFF2BB6C7),
                        Brand.green,
                      ],
                      stops: [0.0, 0.6, 1.0],
                    ),
                    boxShadow: const [
                      BoxShadow(
                          color: Color(0x4D16A0D9),
                          blurRadius: 30,
                          offset: Offset(0, 14)),
                    ],
                  ),
                  child: Stack(
                    children: [
                      const Ico('card', size: 26, color: Colors.white),
                      Positioned(
                        bottom: 30,
                        left: 0,
                        child: Text('•••• 4242',
                            style: tw(FontWeight.w800, 15, Colors.white, 2)),
                      ),
                      Positioned(
                        bottom: 12,
                        left: 0,
                        child: Text('MAP CARS · Visa',
                            style: tw(FontWeight.w700, 11,
                                Colors.white.withValues(alpha: 0.85))),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

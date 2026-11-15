import 'dart:async';

import 'package:flutter/material.dart';



// Promo pictures at the top of the store: slides by itself, can be swiped,

// and the dots show which one is on screen.

class BannerCarousel extends StatefulWidget {

  final List<String> images;

  final Duration interval;



  const BannerCarousel({

    super.key,

    required this.images,

    this.interval = const Duration(seconds: 4),

  });



  @override

  State<BannerCarousel> createState() => _BannerCarouselState();

}



class _BannerCarouselState extends State<BannerCarousel> {

  final _controller = PageController();

  Timer? _timer;

  int _page = 0;



  @override

  void initState() {

    super.initState();

    _startTimer();

  }



  void _startTimer() {

    _timer?.cancel();

    _timer = Timer.periodic(widget.interval, (_) {

      if (!_controller.hasClients) return;

      _controller.animateToPage(

        (_page + 1) % widget.images.length,

        duration: const Duration(milliseconds: 450),

        curve: Curves.easeInOut,

      );

    });

  }



  @override

  void dispose() {

    _timer?.cancel();

    _controller.dispose();

    super.dispose();

  }



  @override

  Widget build(BuildContext context) {

    // 2:1 on a phone; capped so it doesn't fill the page on a wide screen

    return ConstrainedBox(

      constraints: const BoxConstraints(maxHeight: 280),

      child: AspectRatio(

        aspectRatio: 2,

        // A soft navy shadow lifts the banner off the page

        child: DecoratedBox(

          decoration: BoxDecoration(

            borderRadius: BorderRadius.circular(18),

            boxShadow: const [

              BoxShadow(

                color: Color(0x290F2A5F),

                blurRadius: 16,

                offset: Offset(0, 6),

              ),

            ],

          ),

          child: ClipRRect(

            borderRadius: BorderRadius.circular(18),

            child: Stack(

              children: [

                PageView.builder(

                  controller: _controller,

                  itemCount: widget.images.length,

                  onPageChanged: (page) {

                    setState(() {

                      _page = page;

                    });

                    _startTimer(); // a swipe gets its full time on screen

                  },

                  itemBuilder: (context, index) => Image.asset(

                    widget.images[index],

                    fit: BoxFit.cover,

                    width: double.infinity,

                  ),

                ),

                Positioned(

                  left: 0,

                  right: 0,

                  bottom: 8,

                  child: Row(

                    mainAxisAlignment: MainAxisAlignment.center,

                    children: [

                      for (var i = 0; i < widget.images.length; i++)

                        AnimatedContainer(

                          key: ValueKey('banner-dot-$i'),

                          duration: const Duration(milliseconds: 250),

                          margin: const EdgeInsets.symmetric(horizontal: 3),

                          width: i == _page ? 18 : 7,

                          height: 7,

                          decoration: BoxDecoration(

                            color: i == _page ? Colors.white : Colors.white54,

                            borderRadius: BorderRadius.circular(4),

                          ),

                        ),

                    ],

                  ),

                ),

              ],

            ),

          ),

        ),

      ),

    );

  }

}
import 'dart:io';
import 'dart:ui' as ui;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';

import '../api.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets.dart';
import 'sheets.dart';

/// A photo or video the member picked, ready to upload.
class PickedMedia {
  final Uint8List bytes;
  final String kind, ext, contentType;
  final String? file;
  final int? duration;
  PickedMedia(this.bytes, this.kind, this.ext, this.contentType, {this.file, this.duration});
}

/// Asks where the photo or video comes from, then picks and checks it (photos are resized on the phone).
Future<PickedMedia?> pickChatMedia(BuildContext context) async {
  final choice = await kSheet<String>(context, (c) {
    Widget row(String v, IconData ic, String t) => ListTile(leading: Icon(ic), title: Text(t, style: const TextStyle(fontWeight: FontWeight.w600)), onTap: () => Navigator.pop(c, v));
    return Column(mainAxisSize: MainAxisSize.min, children: [
      const Text('Send a photo or video', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
      const SizedBox(height: 8),
      row('photo', Icons.photo_library_outlined, 'Choose a photo'),
      if (!kIsWeb) row('camera', Icons.photo_camera_outlined, 'Take a photo'),
      row('video', Icons.video_library_outlined, 'Choose a video (up to 1 minute)'),
      if (!kIsWeb) row('record', Icons.videocam_outlined, 'Record a video'),
    ]);
  });
  if (choice == null) return null;
  final picker = ImagePicker();
  if (choice == 'photo' || choice == 'camera') {
    final x = await picker.pickImage(source: choice == 'camera' ? ImageSource.camera : ImageSource.gallery, maxWidth: 1600, maxHeight: 1600, imageQuality: 80);
    if (x == null) return null;
    final n = x.name.toLowerCase();
    final (ext, type) = n.endsWith('.png') ? ('png', 'image/png') : n.endsWith('.webp') ? ('webp', 'image/webp') : ('jpg', 'image/jpeg');
    return PickedMedia(await x.readAsBytes(), 'image', ext, type);
  }
  final x = await picker.pickVideo(source: choice == 'record' ? ImageSource.camera : ImageSource.gallery, maxDuration: const Duration(seconds: 60));
  if (x == null) return null;
  final size = await x.length();
  if (!context.mounted) return null;
  if (size > 15 * 1024 * 1024) {
    toast(context, 'That video is too big. Please send one under 15 MB (about a minute).');
    return null;
  }
  int? secs;
  if (!kIsWeb) {
    final v = VideoPlayerController.file(File(x.path));
    try {
      await v.initialize();
      secs = v.value.duration.inSeconds;
    } catch (_) {/* unknown length */} finally {
      v.dispose();
    }
  }
  if (!context.mounted) return null;
  if (secs != null && secs > 65) {
    toast(context, 'Please send a video of 1 minute or less.');
    return null;
  }
  final n = x.name.toLowerCase();
  final (ext, type) = n.endsWith('.3gp') ? ('3gp', 'video/3gpp') : n.endsWith('.webm') ? ('webm', 'video/webm') : n.endsWith('.mov') ? ('mov', 'video/quicktime') : ('mp4', 'video/mp4');
  return PickedMedia(await x.readAsBytes(), 'video', ext, type, file: kIsWeb ? null : x.path, duration: secs);
}

/// Photo or video bubble. Media from the other person stays blurred until tapped, so nobody is shown an unwanted image.
class MediaBubble extends StatefulWidget {
  final Message msg;
  final bool mine, hidden;
  final VoidCallback onReveal;
  const MediaBubble({super.key, required this.msg, required this.mine, required this.hidden, required this.onReveal});
  @override
  State<MediaBubble> createState() => _MediaBubbleState();
}

class _MediaBubbleState extends State<MediaBubble> {
  String? _url;
  bool _error = false;
  Message get m => widget.msg;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (m.mediaPath == null || m.localBytes != null) return;
    try {
      final u = await Api.mediaUrl(m.mediaPath!);
      if (mounted) setState(() => _url = u);
    } catch (_) {
      if (mounted) setState(() => _error = true);
    }
  }

  void _open() {
    if (widget.hidden) return widget.onReveal();
    if (m.kind == 'video') {
      Navigator.push(context, MaterialPageRoute(builder: (_) => VideoScreen(url: _url, file: m.localFile)));
    } else if (_url != null || m.localBytes != null) {
      Navigator.push(context, PageRouteBuilder(opaque: false, pageBuilder: (_, _, _) => PhotoViewer(url: _url, bytes: m.localBytes, cacheKey: m.mediaPath)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    final w = MediaQuery.of(context).size.width * .64;
    Widget content;
    if (_error) {
      content = SizedBox(width: w, height: 120, child: Center(child: Text("Couldn't load", style: TextStyle(color: p.muted, fontSize: 13))));
    } else if (m.kind == 'video') {
      content = Container(
        width: w,
        height: w * .75,
        color: const Color(0xFF1A0D13),
        child: Center(child: Icon(Icons.play_circle_fill_rounded, color: Colors.white.withValues(alpha: .9), size: 54)),
      );
    } else if (m.localBytes != null) {
      content = Image.memory(m.localBytes!, width: w, fit: BoxFit.cover);
    } else if (_url != null) {
      content = CachedNetworkImage(
        imageUrl: _url!,
        cacheKey: m.mediaPath, // the signed link changes every hour; the file does not
        width: w,
        fit: BoxFit.cover,
        placeholder: (_, _) => Silver(child: Bone(width: w, height: w * .75, radius: 16)),
        errorWidget: (_, _, _) => SizedBox(width: w, height: 120, child: Center(child: Text("Couldn't load", style: TextStyle(color: p.muted, fontSize: 13)))),
      );
    } else {
      content = Silver(child: Bone(width: w, height: w * .75, radius: 16));
    }
    if (widget.hidden) {
      content = Stack(alignment: Alignment.center, children: [
        ImageFiltered(imageFilter: ui.ImageFilter.blur(sigmaX: 22, sigmaY: 22), child: ColorFiltered(colorFilter: const ColorFilter.mode(Colors.black26, BlendMode.darken), child: content)),
        Column(mainAxisSize: MainAxisSize.min, children: [
          Text(m.kind == 'video' ? '🎥 Video' : '📷 Photo', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15)),
          const Text('Tap to view', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 12)),
        ]),
      ]);
    }
    return Opacity(
      opacity: m.pending ? .65 : 1,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 3),
        padding: const EdgeInsets.all(4),
        constraints: BoxConstraints(maxHeight: w * 1.35),
        decoration: BoxDecoration(color: m.failed ? K.danger : widget.mine ? K.g1.withValues(alpha: .18) : p.surface2, borderRadius: BorderRadius.circular(20)),
        child: GestureDetector(
          onTap: _open,
          child: ClipRRect(borderRadius: BorderRadius.circular(16), child: Semantics(label: m.kind == 'video' ? 'Video' : 'Photo', button: true, child: content)),
        ),
      ),
    );
  }
}

class PhotoViewer extends StatelessWidget {
  final String? url, cacheKey;
  final Uint8List? bytes;
  const PhotoViewer({super.key, this.url, this.bytes, this.cacheKey});
  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: Colors.black.withValues(alpha: .94),
        body: Stack(children: [
          Positioned.fill(
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: InteractiveViewer(
                maxScale: 4,
                child: Center(child: bytes != null ? Image.memory(bytes!) : CachedNetworkImage(imageUrl: url!, cacheKey: cacheKey, fit: BoxFit.contain)),
              ),
            ),
          ),
          SafeArea(child: Align(alignment: Alignment.topRight, child: IconButton(icon: const Icon(Icons.close, color: Colors.white), tooltip: 'Close', onPressed: () => Navigator.pop(context)))),
        ]),
      );
}

class VideoScreen extends StatefulWidget {
  final String? url, file;
  const VideoScreen({super.key, this.url, this.file});
  @override
  State<VideoScreen> createState() => _VideoScreenState();
}

class _VideoScreenState extends State<VideoScreen> {
  VideoPlayerController? _c;
  bool _error = false;

  @override
  void initState() {
    super.initState();
    final c = widget.file != null && !kIsWeb ? VideoPlayerController.file(File(widget.file!)) : widget.url != null ? VideoPlayerController.networkUrl(Uri.parse(widget.url!)) : null;
    if (c == null) {
      _error = true;
      return;
    }
    _c = c;
    c.initialize().then((_) {
      if (!mounted) return;
      setState(() {});
      c.play();
    }).catchError((_) {
      if (mounted) setState(() => _error = true);
    });
    c.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _c?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = _c;
    final ready = c != null && c.value.isInitialized;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(backgroundColor: Colors.black, foregroundColor: Colors.white, elevation: 0),
      body: Center(
        child: _error
            ? const Text("Couldn't play this video.", style: TextStyle(color: Colors.white70))
            : !ready
                ? const CircularProgressIndicator(color: Colors.white)
                : GestureDetector(
                    onTap: () => c.value.isPlaying ? c.pause() : c.play(),
                    child: Stack(alignment: Alignment.center, children: [
                      AspectRatio(aspectRatio: c.value.aspectRatio, child: VideoPlayer(c)),
                      if (!c.value.isPlaying) const Icon(Icons.play_circle_fill_rounded, color: Colors.white, size: 72),
                      Positioned(left: 0, right: 0, bottom: 0, child: VideoProgressIndicator(c, allowScrubbing: true, colors: const VideoProgressColors(playedColor: K.g1))),
                    ]),
                  ),
      ),
    );
  }
}

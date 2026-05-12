import 'package:flutter/material.dart';
import 'package:flclashx/views/profiles/profiles.dart';
import 'package:flclashx/views/proxies/proxies.dart';
import 'package:flclashx/views/about.dart';

class SettingsView extends StatelessWidget {
  const SettingsView({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Настройки'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Подписки', icon: Icon(Icons.cloud_download)),
              Tab(text: 'Прокси', icon: Icon(Icons.bolt)),
              Tab(text: 'О приложении', icon: Icon(Icons.info_outline)),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            ProfilesView(),
            ProxiesView(),
            AboutView(),
          ],
        ),
      ),
    );
  }
}

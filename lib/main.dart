import 'package:flutter/material.dart' hide Route;

import 'router.dart';

void main() => runApp(MyApp());

class MyApp extends StatelessWidget {
  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MediaQuery(
      data: MediaQueryData.fromWindow(WidgetsBinding.instance.window),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: SafeArea(
          child: Router(
            defaultPath: '/foo1',
            // defaultPath: '/foo2/c',
            child: MatchRoute(
              routes: <Route>[
                Route(
                  '/foo1',
                  () => MyPage(
                    title: 'Page 1',
                    linkTo: '/foo2',
                    color: Colors.redAccent,
                  ),
                ),
                Route(
                  '/foo2',
                  () => MyPage(
                    title: 'Page 2',
                    linkTo: '/foo3',
                    color: Colors.blueAccent,
                    child: Tabs(),
                  ),
                ),
                Route(
                  '/foo3',
                  () => MyPage(
                    title: 'Page 3',
                    linkTo: '/foo1',
                    color: Colors.greenAccent,
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

class MyPage extends StatelessWidget {
  MyPage({this.title, this.linkTo, this.color, this.child});

  final String title;
  final String linkTo;
  final Color color;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 380,
      height: 400,
      child: Material(
        color: color,
        child: Column(
          children: <Widget>[
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                FlatButton(
                  child: Icon(Icons.arrow_left),
                  onPressed: () {
                    Router.of(context).back();
                  },
                ),
                Expanded(
                  child: Center(
                    child: Text(title, style: TextStyle(fontSize: 36.0)),
                  ),
                ),
                FlatButton(
                  child: Icon(Icons.arrow_right),
                  onPressed: () {
                    Router.of(context).forward();
                  },
                ),
              ],
            ),
            RaisedButton(
              child: Text('Go to $linkTo'),
              onPressed: () {
                Router.of(context).push(linkTo);
              },
            ),
            if (child != null)
              Padding(
                padding: EdgeInsets.all(12.0),
                child: child,
              ),
          ],
        ),
      ),
    );
  }
}

class Tabs extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return NavigationBoundary(
      defaultPath: '/a',
      child: Container(
        color: Colors.grey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            TabContent(),
            TabBar(),
          ],
        ),
      ),
    );
  }
}

class TabContent extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final NavigationEntry tabEntry = Router.of(context).currentEntry;
    return Padding(
      padding: const EdgeInsets.all(4.0),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12.0, vertical: 42.0),
        color: Colors.white,
        child: Text(
          'We are on tab: `${tabEntry.path}` (full path: `${tabEntry.fullPath}`)',
          style: TextStyle(fontSize: 20),
        ),
      ),
    );
  }
}

class TabBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(child: TabButton(label: 'Tab a', linkTo: '/a')),
        Expanded(child: TabButton(label: 'Tab b', linkTo: '/b')),
        Expanded(child: TabButton(label: 'Tab c', linkTo: '/c')),
      ],
    );
  }
}

class TabButton extends StatelessWidget {
  const TabButton({@required this.label, @required this.linkTo});

  final String label;
  final String linkTo;

  @override
  Widget build(BuildContext context) {
    return FlatButton(
      child: Text(label),
      onPressed: () {
        // Router.of(context).push(linkTo);
        Router.of(context).replace(linkTo);
      },
    );
  }
}

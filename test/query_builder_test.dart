import 'package:mongo_realtime/mongo_realtime.dart';
import 'package:test/test.dart';

void main() {
  test('or blocks stay grouped and combine with where clauses through and', () {
    final client = MongoRealtime('ws://localhost:3000');
    final users = client.collection('users');

    final filter =
        users
            .where('name', matches: 'admin')
            .or((q) {
              q.where('age', isGreaterThan: 18);
              q.where('status', isEqualTo: 'active');
            })
            .or((q) {
              q.where('teeth', isLessOrEqualTo: 32);
              q.where('teeth', isEqualTo: 40);
            })
            .definition
            .filter;

    expect(filter, <String, dynamic>{
      r'$and': <Map<String, dynamic>>[
        {
          'name': <String, dynamic>{r'$regex': 'admin'},
        },
        {
          r'$or': <Map<String, dynamic>>[
            {
              'age': <String, dynamic>{r'$gt': 18},
            },
            {'status': 'active'},
          ],
        },
        {
          r'$or': <Map<String, dynamic>>[
            {
              'teeth': <String, dynamic>{r'$lte': 32},
            },
            {'teeth': 40},
          ],
        },
      ],
    });
  });
}

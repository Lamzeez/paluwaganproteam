import 'dart:convert';
import 'package:http/http.dart' as http;

class QuoteService {
  Future<String> getRandomQuote() async {
    try {
      final response = await http.get(Uri.parse('https://zenquotes.io/api/random'));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return "${data[0]['q']} \n— ${data[0]['a']}";
      }
    } catch (e) {
      print('Error fetching quote: $e');
    }
    return "The best way to save money is not to lose it.";
  }
}
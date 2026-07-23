class Suggestion {
  final String placeId;
  final String description;
  final String? mainText;
  final String? secondaryText;
  final List<String>? terms;
  final List<String>? types;
  Suggestion(this.placeId, this.description,
      {this.mainText, this.secondaryText, this.terms, this.types});

  @override
  String toString() {
    return "Suggestion(description:'$description', placeId:'$placeId', main_text:${mainText == null ? 'null' : "'$mainText'"}, secondary_text:${secondaryText == null ? 'null' : "'$secondaryText'"}, terms:${terms == null ? 'null' : terms.toString()}, types:${types == null ? 'null' : types.toString()})";
  }
}

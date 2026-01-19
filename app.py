from flask import Flask, render_template, send_from_directory, request, jsonify, redirect, url_for
import os
from PIL import Image
from wordcloud import WordCloud
import json
import matplotlib.colors

app = Flask(__name__)

# Define paths
WORDCLOUD_PATH = os.path.join('static', 'png', 'wordcloud.png')
VOTES_FILE = 'votes.json'

@app.route('/')
def index():
    return render_template('index.html')

@app.route('/translations/<lang>.json')
def translations(lang):
    translations_dir = os.path.join(app.root_path, 'translations')
    return send_from_directory(translations_dir, f'{lang}.json')

@app.route('/wordcloud')
def wordcloud():
    return render_template('wordcloud.html')

@app.route('/submit-vote', methods=['POST'])
def submit_vote():
    """Submit vote with selected items"""
    data = request.get_json()
    selected_items = data.get('items', [])
    
    if len(selected_items) != 3:
        return jsonify({'error': 'Must select exactly 3 items'}), 400
    
    # Load current votes
    try:
        with open(VOTES_FILE, 'r', encoding='utf-8') as f:
            votes = json.load(f)
    except FileNotFoundError:
        votes = {
            "item1": 0, "item2": 0, "item3": 0, "item4": 0,
            "item5": 0, "item6": 0, "item7": 0, "item8": 0,
            "item9": 0, "item10": 0, "item11": 0, "item12": 0,
            "totalvotes": 0
        }
    
    # Increment votes for selected items
    for item_key in selected_items:
        if item_key in votes:
            votes[item_key] += 1
    
    # Increment total votes
    votes['totalvotes'] = votes.get('totalvotes', 0) + 1
    
    # Save votes
    with open(VOTES_FILE, 'w', encoding='utf-8') as f:
        json.dump(votes, f, indent=4)
    
    # Generate wordcloud with default language (en)
    generate_wordcloud(votes, language='en')
    
    return jsonify({'success': True, 'redirect': url_for('wordcloud')})

@app.route('/regenerate-wordcloud', methods=['POST'])
def regenerate_wordcloud():
    """Regenerate wordcloud with specified language"""
    data = request.get_json()
    language = data.get('language', 'en')
    
    # Load current votes
    try:
        with open(VOTES_FILE, 'r', encoding='utf-8') as f:
            votes = json.load(f)
    except FileNotFoundError:
        votes = {
            "item1": 0, "item2": 0, "item3": 0, "item4": 0,
            "item5": 0, "item6": 0, "item7": 0, "item8": 0,
            "item9": 0, "item10": 0, "item11": 0, "item12": 0,
            "totalvotes": 0
        }
    
    # Generate wordcloud with specified language
    generate_wordcloud(votes, language=language)
    
    # Return the image path with cache busting
    import time
    return jsonify({'image_path': url_for('static', filename='png/wordcloud.png') + f'?t={int(time.time())}'})

def generate_wordcloud(votes, language='en'):
    """Generate word cloud image from vote counts"""
    # Filter out totalvotes from vote counts
    vote_counts = {k: v for k, v in votes.items() if k != 'totalvotes'}
    
    if not vote_counts or sum(vote_counts.values()) == 0:
        # Create a blank white image instead of trying to generate empty word cloud
        img = Image.new('RGB', (1200, 600), color='white')
        img.save(WORDCLOUD_PATH)
        return WORDCLOUD_PATH
    
    # Load translations to get item names
    translations_path = os.path.join('translations', f'{language}.json')
    try:
        with open(translations_path, 'r', encoding='utf-8') as f:
            translations = json.load(f)
    except:
        # Fallback to English if translation file not found
        with open('translations/en.json', 'r', encoding='utf-8') as f:
            translations = json.load(f)
    
    # Create word-frequency dictionary
    word_freq = {}
    for item_id, count in vote_counts.items():
        if count > 0:
            # Get translated name for this item
            # item_id is already in format "item1", "item2", etc.
            item_name = translations.get(item_id, f"Item {item_id}")
            word_freq[item_name] = count
    
    # Only generate if we have words
    if not word_freq:
        img = Image.new('RGB', (1200, 600), color='white')
        img.save(WORDCLOUD_PATH)
        return WORDCLOUD_PATH
    
    # Generate word cloud
    # Use appropriate font based on language
    font_path = None
    fonts_dir = os.path.join('static', 'fonts')
    if language == 'he':
        font_path = os.path.join(fonts_dir, 'EzerEuro-Medium.otf')
    elif language == 'ar':
        font_path = os.path.join(fonts_dir, 'Cairo-VariableFont.ttf')
    elif language == 'en':
        font_path = os.path.join(fonts_dir, 'EzerEuro-Medium.otf')
    
    # Use default margin
    margin = 10
    hex_colors = ['#927BEF', '#F15F30', '#F6920F', '#0556E3', '#F4F3E8', '#6D4DEA', "#034679", '#C87FB7','#3A94E7']
    custom_cmap_discrete = matplotlib.colors.ListedColormap(hex_colors, name='custom_discrete')
    wc = WordCloud(
        width=1200,
        height=1200,
        mode='RGBA', 
        background_color=None,
        font_path=font_path,
        relative_scaling=0.5,
        colormap=custom_cmap_discrete,
        margin=margin,
    ).generate_from_frequencies(word_freq)
    
    # Save to file
    wc.to_file(WORDCLOUD_PATH)
    return WORDCLOUD_PATH

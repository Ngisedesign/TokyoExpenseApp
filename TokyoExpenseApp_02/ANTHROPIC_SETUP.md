# Anthropic API Setup

This app uses Claude AI (Anthropic) to parse receipt images with high accuracy.

## Setup Instructions

### 1. Get Your API Key

1. Go to [Anthropic Console](https://console.anthropic.com/)
2. Sign up or log in
3. Navigate to **API Keys**
4. Click **Create Key**
5. Copy your API key (starts with `sk-ant-api03-...`)

### 2. Add API Key to the App

1. Open `TokyoExpenseApp_02/Config/APIKeys.swift`
2. Replace `YOUR_API_KEY_HERE` with your actual API key:

```swift
enum APIKeys {
    static let anthropic = "sk-ant-api03-YOUR_ACTUAL_KEY_HERE"
}
```

3. Save the file

**Important:** The `APIKeys.swift` file is gitignored, so your key won't be committed to version control.

### 3. Build and Run

That's it! The app will now use Claude Vision to parse receipts when you:
- Take a photo with the camera
- Select an image from your photo library

## How It Works

1. You capture or select a receipt image
2. The image is sent to Claude API
3. Claude analyzes the receipt and extracts:
   - **Merchant name** (e.g., "LAWSON", "Uber")
   - **Total amount** (in Yen)
   - **Date** (automatically formatted)
   - **Category** (Food/Per Diem, Transport, or Other)
   - **Description** (e.g., "Lunch", "Dinner", "Coffee", "Train") *[Coming Soon]*
   - **Confidence score** (0-100%)
4. The form is auto-filled with the extracted data
5. You can review and edit before saving

## Features

✅ **High Accuracy** - Claude Vision is excellent at Japanese receipts
✅ **One-Shot Parsing** - No complex OCR + parsing pipeline
✅ **Category Detection** - Automatically categorizes expenses
✅ **Date Extraction** - Finds dates in various formats
✅ **Error Handling** - Shows clear error messages if parsing fails

## Cost

Anthropic charges per API call. As of 2024:
- Claude 3.5 Sonnet: ~$0.003 per image (very affordable)
- 1000 receipts = ~$3

Check [Anthropic Pricing](https://www.anthropic.com/pricing) for current rates.

## Troubleshooting

**Error: "Failed to parse receipt: API Error (401)"**
- Check that your API key is correct in `APIKeys.swift`
- Make sure the key starts with `sk-ant-api03-`

**Error: "Failed to parse receipt: API Error (429)"**
- You've hit rate limits
- Wait a few seconds and try again
- Check your API usage in Anthropic Console

**Error: "Failed to convert image to JPEG"**
- The image format may be unsupported
- Try taking a new photo instead

**Parsing is inaccurate**
- Make sure the receipt is clear and well-lit
- Check that all text is visible (not blurry or cut off)
- You can manually edit any field after auto-fill

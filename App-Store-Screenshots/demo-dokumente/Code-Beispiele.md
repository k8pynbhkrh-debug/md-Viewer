# Code-Schnipsel

Inline-Code wie `git rebase -i` wird ebenso hervorgehoben wie ganze Blöcke.

## Swift

```swift
struct DocumentView: View {
    let fileURL: URL

    var body: some View {
        ScrollView {
            Markdown(content)
                .padding()
                .frame(maxWidth: 720)
        }
        .navigationTitle(fileURL.lastPathComponent)
    }
}
```

## Python

```python
def render(path: str) -> str:
    with open(path, encoding="utf-8") as f:
        return markdown(f.read(), extensions=["tables", "fenced_code"])
```

## Shell

```sh
xcodebuild -scheme "md Viewer" -configuration Release \
  -archivePath build/app.xcarchive archive
```

## JSON

```json
{
  "name": "md Viewer",
  "bundleId": "com.eribert.md-Viewer",
  "offline": true,
  "collectsData": false
}
```

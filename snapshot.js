#import "SnapshotHelper.js"

var target = UIATarget.localTarget();
var app = target.frontMostApp();
var window = app.mainWindow();

app.navigationBar().rightButton().tap();
app.keyboard().typeString("Groceries");
app.navigationBar().leftButton().tap();
app.navigationBar().rightButton().tap();
app.keyboard().typeString("Pharmacy");
app.navigationBar().leftButton().tap();

target.delay(2)
captureLocalizedScreenshot("1-blist")

app.mainWindow().tableViews()[0].cells()[0].tap();
app.navigationBar().rightButton().tap();
app.keyboard().typeString("spaghetti");
app.navigationBar().rightButton().tap();
app.keyboard().typeString("cheese");
app.navigationBar().rightButton().tap();
app.keyboard().typeString("bread");
app.navigationBar().rightButton().tap();
app.keyboard().typeString("milk");
app.navigationBar().rightButton().tap();
app.keyboard().typeString("eggs");
app.navigationBar().rightButton().tap();
app.keyboard().typeString("chocolate");
app.mainWindow().tableViews()[0].cells()[1].tap();
app.keyboard().typeString("dark");
app.navigationBar().rightButton().tap();
app.keyboard().typeString("beer");
app.navigationBar().leftButton().tap();
target.delay(2)
app.mainWindow().tableViews()[0].scrollToElementWithPredicate("name beginswith 'spaghetti'")
target.delay(2)
app.mainWindow().tableViews()[0].cells()[0].tap();
app.mainWindow().tableViews()[0].cells()[1].tap();
app.mainWindow().tableViews()[0].cells()[3].tap();
app.mainWindow().tableViews()[0].cells()[4].tap();

target.delay(2)
captureLocalizedScreenshot("2-blist")

// MyDocument.m

// Created by koch in July, 2000.

#define NAIRN  // if this is commented out, Nairn's additions are not added
#define ROOTFILE  // if this is commented out, the old ROOTFILE behavior applies

#import "UseMitsu.h"

#import <AppKit/AppKit.h>
#import <Carbon/Carbon.h>
#import "MyDocument.h"

#ifdef MITSU_PDF
#import "MyPDFView.h"
#else
#import "MyView.h"
#endif

#import "PrintView.h"
#import "PrintBitmapView.h"
#import "TSPreferences.h"
#import "TSWindowManager.h"
#import "extras.h"
#import "globals.h"
#import "Autrecontroller.h"
#import "MyDocumentToolbar.h"
#import "TSAppDelegate.h"
#import "MyTextView.h"
#import "EncodingSupport.h"
#import "MacroMenuController.h"
#import "MyDocumentController.h"


#define SUD [NSUserDefaults standardUserDefaults]
#define Mcomment 1
#define Muncomment 2
#define Mindent 3
#define Munindent 4

#define COLORTIME  0.02
#define COLORLENGTH 5000

// #define COLORTIME  .02
// #define COLORLENGTH 500000

@implementation MyDocument : NSDocument

//-----------------------------------------------------------------------------
- (id)init
//-----------------------------------------------------------------------------
{
    [super init];
    
    errorNumber = 0;
    whichError = 0;
    makeError = NO;
    colorStart = 0; 
    colorEnd = 0; 
    returnline = NO; 
    tagLine = NO;
    texRep = nil;
    fileIsTex = YES;
    mSelection = nil;
    fastColor = NO;
    fastColorBackTeX = NO;
    rootDocument = nil;
    warningGiven = NO;
    omitShellEscape = NO;
        
    encoding = [[MyDocumentController sharedDocumentController] encoding];
    
    return self;
}

//-----------------------------------------------------------------------------
- (void)dealloc 
//-----------------------------------------------------------------------------
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
#ifdef MITSU_PDF
     [[NSNotificationCenter defaultCenter] removeObserver:pdfView];// mitsu 1.29 (O) need to remove here, otherwise updateCurrentPage fails 
#endif
    if (syntaxColoringTimer != nil) 
    {
        [syntaxColoringTimer invalidate];
        [syntaxColoringTimer release];
    }
    if (tagTimer != nil) 
    {
        [tagTimer invalidate];
        [tagTimer release];
    }
    [commentColor release];
    [commandColor release];
    [markerColor release];
    [mSelection release];
    [textStorage release];
    
/* toolbar stuff */
    [typesetButton release];
    [programButton release];
    [typesetButtonEE release];
    [programButtonEE release];
    [tags release];
    [popupButton release];
    [previousButton release];
    [nextButton release];
    [gotopageOutlet release];
    [magnificationOutlet release];
    [macroButton release]; // mitsu 1.29 -- I for got this
    
#ifdef MITSU_PDF
    [mouseModeMatrix release]; // mitsu 1.29 (O)
#endif
    
/* others */

    [super dealloc];
}

- (id) pdfView;
{
    return pdfView;
}

- (NSString *)windowNibName {
    // Override returning the nib file name of the document
    return @"MyDocument";
}

- (void)printShowingPrintPanel:(BOOL)flag 
{
    id			printView;
    NSPrintOperation	*printOperation;
    NSString		*imagePath;
#ifndef ROOTFILE
    NSString		*projectPath, *nameString;
#endif
    NSString		*theSource;
    id			aRep;
    int			result;

    if (myImageType == isTeX) {
    
    
    if (! externalEditor) {
        theSource = [[self textView] string]; 
        if ([self checkMasterFile:theSource forTask:RootForPrinting]) 
            return;
#ifdef ROOTFILE
        if ([self checkRootFile_forTask:RootForPrinting]) 
            return;
#endif
        }

#ifndef ROOTFILE
        projectPath = [[[self fileName] stringByDeletingPathExtension] stringByAppendingPathExtension:@"texshop"];
        if ([[NSFileManager defaultManager] fileExistsAtPath: projectPath]) {
            NSString *projectRoot = [NSString stringWithContentsOfFile: projectPath];
            if ([projectRoot isAbsolutePath]) {
                nameString = [NSString stringWithString:projectRoot];
                }
            else {
                nameString = [[self fileName] stringByDeletingLastPathComponent];
                nameString = [[nameString stringByAppendingString:@"/"] 
                    stringByAppendingString: [NSString stringWithContentsOfFile: projectPath]];
                nameString = [nameString stringByStandardizingPath];
            }
            imagePath = [[nameString stringByDeletingPathExtension] stringByAppendingPathExtension:@"pdf"];
            }
        else
#endif
            imagePath = [[[self fileName] stringByDeletingPathExtension] stringByAppendingPathExtension:@"pdf"];
    }
    else if (myImageType == isPDF)
        imagePath = [[[self fileName] stringByDeletingPathExtension] stringByAppendingPathExtension:@"pdf"];
    else if ((myImageType == isJPG) || (myImageType == isTIFF))
        imagePath = [self fileName];
    else
        imagePath = [self fileName];

    aRep = nil;
    if ([[NSFileManager defaultManager] fileExistsAtPath: imagePath]) {
        if ((myImageType == isTeX) || (myImageType == isPDF))
            aRep = [[NSPDFImageRep imageRepWithContentsOfFile: imagePath] retain];
        else if (myImageType == isJPG)
            aRep = [[NSImageRep imageRepWithContentsOfFile: imagePath] retain];
        else if (myImageType == isTIFF)
            aRep = [[NSImageRep imageRepWithContentsOfFile: imagePath] retain];
        else
            return;
        if (aRep == nil) return;
        if ((myImageType == isJPG) || (myImageType == isTIFF)) 
            printView = [[PrintBitmapView alloc] initWithBitmapRep: aRep];
        else
            printView = [[PrintView alloc] initWithRep: aRep];
        printOperation = [NSPrintOperation printOperationWithView:printView
            printInfo: [self printInfo]];
        if ((myImageType == isJPG) || (myImageType == isTIFF))
            [printView setBitmapPrintOperation: printOperation]; 
        else
            [printView setPrintOperation: printOperation];
        [printOperation setShowPanels:flag];
        [printOperation runOperation];
        [printView release];
	}
    else if (myImageType == isTeX)
        result = [NSApp runModalForWindow: printRequestPanel];
}
    

- (void)windowControllerDidLoadNib:(NSWindowController *)aController
{    
    BOOL                spellExists;
    NSString		*imagePath;
#ifndef ROOTFILE
    NSString		*projectPath, *nameString;
#endif
#ifdef ROOTFILE
    NSString		*theSource;
#endif
    NSString		*fileExtension;
#ifndef MITSU_PDF
    NSRect		topLeftRect;
    NSPoint		topLeftPoint;
#endif
    NSRange		myRange;
    unsigned		length;
    BOOL		imageFound;
    NSString		*theFileName;
    float		r, g, b;
    int			defaultcommand;
    NSSize		contentSize;
    NSColor		*backgroundColor;
    
    [super windowControllerDidLoadNib:aController];
    
// the code below exists because the spell checker sometimes did not exist
// in Panther developer releases; it is probably not necessary for
// the final release
NS_DURING
    spellExists = YES;
    NSSpellChecker *myChecker = [NSSpellChecker sharedSpellChecker];
NS_HANDLER
    spellExists = NO;
NS_ENDHANDLER

    
/*
    // Added by Greg Landweber to load the autocompletion dictionary
    // This code is modified from the code to load the LaTeX panel
    NSString	*autocompletionPath;
    
    autocompletionPath = [AutoCompletionPathKey stringByStandardizingPath];
    autocompletionPath = [autocompletionPath stringByAppendingPathComponent:@"autocompletion"];
    autocompletionPath = [autocompletionPath stringByAppendingPathExtension:@"plist"];
    if ([[NSFileManager defaultManager] fileExistsAtPath: autocompletionPath]) 
	autocompletionDictionary=[NSDictionary dictionaryWithContentsOfFile:autocompletionPath];
    else
	autocompletionDictionary=[NSDictionary dictionaryWithContentsOfFile:
	 [[NSBundle mainBundle] pathForResource:@"autocompletion" ofType:@"plist"]];
    [autocompletionDictionary retain];
    // end of code added by Greg Landweber
*/
    backgroundColor = [NSColor colorWithCalibratedRed: [SUD floatForKey:background_RKey]
    green:  [SUD floatForKey:background_GKey]
    blue: [SUD floatForKey:background_BKey] 
    alpha:1.0];
    
/*    
    // New
    contentSize = [scrollView contentSize];
    textView = [[MyTextView alloc] initWithFrame: NSMakeRect(0, 0, contentSize.width, contentSize.height)];
    [textView setAutoresizingMask: NSViewWidthSizable];
    [[textView textContainer] setWidthTracksTextView:YES];
    [textView setDelegate:self];
    [textView setAllowsUndo:YES];
    [textView setRichText:NO];
    [textView setUsesFontPanel:YES];
    [textView setFont:[NSFont userFontOfSize:12.0]];
    [textView setBackgroundColor: backgroundColor];
    [scrollView setDocumentView:textView];
    [textView release];
*/
    /* End of New */
    
        /* New forsplit */
        
    
    contentSize = [scrollView contentSize];
    textView1 = [[MyTextView alloc] initWithFrame: NSMakeRect(0, 0, contentSize.width, contentSize.height)];
    [textView1 setAutoresizingMask: NSViewWidthSizable];
    [[textView1 textContainer] setWidthTracksTextView:YES];
    [textView1 setDelegate:self];
    [textView1 setAllowsUndo:YES];
    [textView1 setRichText:NO];
    [textView1 setUsesFontPanel:YES];
    [textView1 setFont:[NSFont userFontOfSize:12.0]];
    [textView1 setBackgroundColor: backgroundColor];
    [scrollView setDocumentView:textView1];
    [textView1 setDocument: self]; // mitsu 1.29 (T2-4) added 
    [textView1 release];
    textView = textView1;
    /* End of New */
// forsplit

    contentSize = [scrollView2 contentSize];
    textView2 = [[MyTextView alloc] initWithFrame: NSMakeRect(0, 0, contentSize.width, contentSize.height)];
    [textView2 setAutoresizingMask: NSViewWidthSizable];
    [[textView2 textContainer] setWidthTracksTextView:YES];
    [textView2 setDelegate:self];
    [textView2 setAllowsUndo:YES];
    [textView2 setRichText:NO];
    [textView2 setUsesFontPanel:YES];
    if (spellExists) 
        [textView2 setContinuousSpellCheckingEnabled:[SUD boolForKey:SpellCheckEnabledKey]];
    [textView2 setFont:[NSFont userFontOfSize:12.0]];
    [textView2 setBackgroundColor: backgroundColor];
    [scrollView2 setDocumentView:textView2];
    [textView2 setDocument: self]; // mitsu 1.29 (T2-4) added 
    [textView2 release];

    textStorage = [textView1 textStorage];
    
    NSLayoutManager *layoutManager = [textView2 layoutManager];
    [textStorage addLayoutManager:layoutManager];
    // For an explanation of the three lines below, see 'setTextView' below
    layoutManager = [textView1 layoutManager];
    [textStorage removeLayoutManager:layoutManager];
    [textStorage addLayoutManager:layoutManager];
    [textStorage retain];
    
    [scrollView2 retain];
    [scrollView2 removeFromSuperview];
    windowIsSplit = NO;
//  endforsplit

    
    externalEditor = [[[NSApplication sharedApplication] delegate] forPreview];
    theFileName = [self fileName];
    [self setupToolbar];
    
    r = [SUD floatForKey:commandredKey];
    g = [SUD floatForKey:commandgreenKey];
    b = [SUD floatForKey:commandblueKey];
    commandColor = [[NSColor colorWithCalibratedRed:r green:g blue:b alpha:1.0] retain];
    r = [SUD floatForKey:commentredKey];
    g = [SUD floatForKey:commentgreenKey];
    b = [SUD floatForKey:commentblueKey];
    commentColor = [[NSColor colorWithCalibratedRed:r green:g blue:b alpha:1.0] retain];
    r = [SUD floatForKey:markerredKey];
    g = [SUD floatForKey:markergreenKey];
    b = [SUD floatForKey:markerblueKey];
    markerColor = [[NSColor colorWithCalibratedRed:r green:g blue:b alpha:1.0] retain];

  doAutoComplete = [SUD boolForKey:AutoCompleteEnabledKey];
  [self fixAutoMenu];


/* when opening an empty document, must open the source editor */         
    if ((theFileName == nil) && (externalEditor))
        externalEditor = NO;
 
    [self registerForNotifications];    
	[self setupFromPreferencesUsingWindowController:aController];

    [pdfView setDocument: self]; /* This was commented out!! Don't do it; needed by Ghostscript; Dick */
    [textView setDelegate: self];
// the next line caused jpg and tiff files to fail, so we do it later
 //   [pdfView resetMagnification]; 
    
   
    whichScript = [SUD integerForKey:DefaultScriptKey];
    [self fixTypesetMenu];
    
    myImageType = isTeX;
    fileExtension = [[self fileName] pathExtension];
    
    if (([fileExtension isEqualToString: @"jpg"]) || 
        ([fileExtension isEqualToString: @"jpeg"]) ||
        ([fileExtension isEqualToString: @"JPG"]) ||
        ([fileExtension isEqualToString: @"tif"]) ||
        ([fileExtension isEqualToString: @"tiff"]))
            ;
#ifndef MITSU_PDF
    else
        [pdfView resetMagnification];
#endif
        
    if (( ! [fileExtension isEqualToString: @"tex"]) && ( ! [fileExtension isEqualToString: @"TEX"])
     && ( ! [fileExtension isEqualToString: @"dtx"]) && ( ! [fileExtension isEqualToString: @"ins"])
     && ( ! [fileExtension isEqualToString: @"sty"]) && ( ! [fileExtension isEqualToString: @"cls"])
// added by mitsu --(N) support for .def, .fd, .ltx. .clo
     && ( ! [fileExtension isEqualToString: @"def"]) && ( ! [fileExtension isEqualToString: @"fd"])
     && ( ! [fileExtension isEqualToString: @"ltx"]) && ( ! [fileExtension isEqualToString: @"clo"])
// end addition
        && ( ! [fileExtension isEqualToString: @""]) && ( ! [fileExtension isEqualToString: @"mp"]) 
        && ( ! [fileExtension isEqualToString: @"mf"]) 
        && ([[NSFileManager defaultManager] fileExistsAtPath: [self fileName]]))
    {
        [self setFileType: fileExtension];
        [typesetButton setEnabled: NO];
        [typesetButtonEE setEnabled: NO];
        myImageType = isOther;
        fileIsTex = NO;
    }
            
/* handle images */

#ifdef MITSU_PDF
	// mitsu 1.29 (S4)-- flipped clip view
	// the following code allows the window to be anchored at top left when scrolled
	[pdfView retain]; // hold it when clipView is released
	NSScrollView *pdfScrollView = [pdfView enclosingScrollView];
	NSClipView *pdfClipView = [pdfScrollView contentView];
	NSRect clipFrame = [pdfClipView frame];
    pdfClipView = [[FlippedClipView alloc] initWithFrame: clipFrame];	// it returns YES for isFlipped
	[pdfScrollView setContentView: pdfClipView];
	[pdfClipView setBackgroundColor: [NSColor windowBackgroundColor]];
	[pdfClipView setDrawsBackground: YES];
	[pdfClipView release];
	[pdfScrollView setDocumentView: pdfView];
	[pdfView release];
        [pdfView setAutoresizingMask: NSViewNotSizable];
	// notofication for scroll
	[[NSNotificationCenter defaultCenter] addObserver:pdfView selector:@selector(wasScrolled:) 
				name:NSViewBoundsDidChangeNotification object:[pdfView superview]];
	// end mitsu 1.29
#endif

    [pdfView setImageType: myImageType];
        
    if (! fileIsTex)
        {
        imageFound = NO;
        imagePath = [self fileName];
        
        if ([fileExtension isEqualToString: @"pdf"]) {
            imageFound = YES;
            texRep = [[NSPDFImageRep imageRepWithContentsOfFile: imagePath] retain];
            [pdfWindow setTitle: [[self fileName] lastPathComponent]]; 
            // [pdfWindow setRepresentedFilename: [self fileName]]; //mitsu July4; 
            // supposed to allow command click of window title to lead to file, but doesn't
            myImageType = isPDF;
            }
        else if (([fileExtension isEqualToString: @"jpg"]) || 
                ([fileExtension isEqualToString: @"jpeg"]) ||
                ([fileExtension isEqualToString: @"JPG"])) {
            imageFound = YES;
            texRep = [[NSBitmapImageRep imageRepWithContentsOfFile: imagePath] retain];
             [pdfWindow setTitle: [[self fileName] lastPathComponent]]; 
             // [pdfWindow setRepresentedFilename: [self fileName]]; //mitsu July4
            myImageType = isJPG;
            [previousButton setEnabled:NO];
            [nextButton setEnabled:NO];
            }
        else if (([fileExtension isEqualToString: @"tiff"]) ||
                ([fileExtension isEqualToString: @"tif"])) {
            imageFound = YES;
            texRep = [[NSBitmapImageRep imageRepWithContentsOfFile: imagePath] retain];
            [pdfWindow setTitle: [[self fileName] lastPathComponent]]; 
            // [pdfWindow setRepresentedFilename: [self fileName]]; //mitsu July4
            myImageType = isTIFF;
            [previousButton setEnabled:NO];
            [nextButton setEnabled:NO];
             }
        else if (([fileExtension isEqualToString: @"dvi"]) || 
                ([fileExtension isEqualToString: @"ps"]) ||
                ([fileExtension isEqualToString:@"eps"]))
            {
                myImageType = isPDF;
                [pdfView setImageType: myImageType];
                // [pdfWindow setRepresentedFilename: [self fileName]]; //mitsu July4
                [self convertDocument];
                return;
            }
            
        if (imageFound) {
                [pdfView setImageType: myImageType];
                [pdfView setImageRep: texRep]; // this releases old one!
#ifndef MITSU_PDF
                if (myImageType == isPDF) {
                    topLeftRect = [texRep bounds];
                    topLeftPoint.x = topLeftRect.origin.x;
                    topLeftPoint.y = topLeftRect.origin.y + topLeftRect.size.height - 1;
                    [pdfView scrollPoint: topLeftPoint];
                    }
#endif

                if (texRep != nil) 
                    [pdfView display];
#ifndef MITSU_PDF
                if ((myImageType == isJPG) || (myImageType == isTIFF))
                [pdfView resetMagnification];
#endif
                [pdfWindow makeKeyAndOrderFront: self];
                return;
                }
        }
 /* end of images */
 if (externalEditor) {
    [self setHasUndoManager: NO];  // so reporting no changes does not lead to error messages
    texTask = nil;
    bibTask = nil;
    indexTask = nil;
    metaFontTask = nil;
    }
  else if (aString != nil) 
    {	
        [textView setString: aString];
        length = [aString length];
        [self setupTags];
        
        if (([SUD boolForKey:SyntaxColoringEnabledKey]) && (fileIsTex)) 
        {
            colorLocation = 0;
            [self fixColor2:0 :length];
           // syntaxColoringTimer = [[NSTimer scheduledTimerWithTimeInterval: COLORTIME target:self selector:@selector(fixColor1:) userInfo:nil repeats:YES] retain];
        }

        // [aString release];  // mitsu 1.29 memory leak fix; aString is autoreleased
        aString = nil;
        texTask = nil;
        bibTask = nil;
        indexTask = nil;
        metaFontTask = nil;
    }
    
  if (! externalEditor) {
    myRange.location = 0;
    myRange.length = 0;
    [textView setSelectedRange: myRange];
    if (spellExists)
        [textView setContinuousSpellCheckingEnabled:[SUD boolForKey:SpellCheckEnabledKey]];
    [textWindow setInitialFirstResponder: textView];
    [textWindow makeFirstResponder: textView];
    }
    
    if (!fileIsTex) 
        return;
        
// changed by mitsu --(J) Typeset command and (J++) Program popup button indicating Program name
    defaultcommand = [SUD integerForKey:DefaultCommandKey];
    switch (defaultcommand) {
        case DefaultCommandTeX: [programButton selectItemWithTitle: @"Plain TeX"]; 
								[programButtonEE selectItemWithTitle: @"Plain TeX"];
								whichEngine = TexEngine;	// just remember the default command
                                break;
        case DefaultCommandLaTeX:   [programButton selectItemWithTitle: @"LaTeX"]; 
                                    [programButtonEE selectItemWithTitle: @"LaTeX"];
									whichEngine = LatexEngine;	// just remember the default command
                                    break;
        case DefaultCommandConTEXt: [programButton selectItemWithTitle: @"ConTeXt"]; 
                                    [programButtonEE selectItemWithTitle: @"ConTeXt"];
									whichEngine = ContextEngine;	// just remember the default command
                                    break;
        }
    [self fixMacroMenu];
    
// end change

/* old code       
    defaultcommand = [SUD integerForKey:DefaultCommandKey];
    switch (defaultcommand) {
        case DefaultCommandTeX: [typesetButton setTitle: @"TeX"]; 
                                [typesetButtonEE setTitle: @"TeX"];
                                break;
        case DefaultCommandLaTeX:   [typesetButton setTitle: @"LaTeX"]; 
                                    [typesetButtonEE setTitle: @"LaTeX"];
                                    break;
        case DefaultCommandConTEXt: [typesetButton setTitle: @"ConTeXt"]; 
                                    [typesetButtonEE setTitle: @"ConTeXt"];
                                    break;
        }
    */

#ifndef ROOTFILE    
    projectPath = [[[self fileName] stringByDeletingPathExtension] stringByAppendingPathExtension:@"texshop"];
    if ([[NSFileManager defaultManager] fileExistsAtPath: projectPath]) {
        NSString *projectRoot = [NSString stringWithContentsOfFile: projectPath];
        if ([projectRoot isAbsolutePath]) {
            nameString = [NSString stringWithString:projectRoot];
        }
        else {
            nameString = [[self fileName] stringByDeletingLastPathComponent];
            nameString = [[nameString stringByAppendingString:@"/"] 
                stringByAppendingString: [NSString stringWithContentsOfFile: projectPath]];
            nameString = [nameString stringByStandardizingPath];
        }
        imagePath = [[nameString stringByDeletingPathExtension] stringByAppendingPathExtension:@"pdf"];
        }
    else
#endif

#ifdef ROOTFILE
    theSource = [[self textView] string];
    if ([self checkMasterFile: theSource forTask:RootForOpening])
        return;
    if ([self checkRootFile_forTask: RootForOpening])
        return;
#endif
        imagePath = [[[self fileName] stringByDeletingPathExtension] stringByAppendingPathExtension:@"pdf"];
    if ([[NSFileManager defaultManager] fileExistsAtPath: imagePath]) {
        texRep = [[NSPDFImageRep imageRepWithContentsOfFile: imagePath] retain]; 
        if (texRep) {
            /* [pdfWindow setTitle: 
                    [[[[self fileName] lastPathComponent] 
                    stringByDeletingPathExtension] stringByAppendingString:@".pdf"]]; */
            [pdfWindow setTitle: [imagePath lastPathComponent]];
            // [pdfWindow setRepresentedFilename: [[[[self fileName] lastPathComponent] 
            //        stringByDeletingPathExtension] stringByAppendingString:@".pdf"]]; //mitsu July4
            [pdfView setImageRep: texRep]; // this releases old one!
#ifndef MITSU_PDF
            topLeftRect = [texRep bounds];
            topLeftPoint.x = topLeftRect.origin.x;
            topLeftPoint.y = topLeftRect.origin.y + topLeftRect.size.height - 1;
            [pdfView scrollPoint: topLeftPoint];
            [pdfView display];
#endif
            [pdfWindow makeKeyAndOrderFront: self];
            }
        }
    else if (externalEditor) {
            [pdfWindow setTitle: [imagePath lastPathComponent]];
            [pdfWindow makeKeyAndOrderFront: self];
        }
// added by mitsu --(A) TeXChar filtering
	[texCommand setDelegate: [EncodingSupport sharedInstance]];
// end addition

}

// added by mitsu --(K) "Unititled-n" for new window
// this method gives a name "Untitled-n" for new documents
-(NSString *)displayName
{
	if ([self fileName] == nil) // file is a new one
	{
                NSString *displayString = [super displayName];
                if (displayString == nil) // these two lines fix a Panther problem
                    return displayString;
                else {
                    NSMutableString *newString = [NSMutableString stringWithString: displayString];
                    [newString replaceOccurrencesOfString: @" " withString: @"-"
						options: 0 range: NSMakeRange(0, [newString length])];
                    // mitsu 1.29 (V)
                    if ([[[[[NSBundle mainBundle] pathForResource:@"MainMenu" ofType:@"nib"] 
				stringByDeletingLastPathComponent] lastPathComponent] 
				isEqualToString: @"Japanese.lproj"] && [newString length]==5)
				[newString appendString: @"-1"];
                    // end mitsu 1.29
                    return newString;
                    }
	}
	return [super displayName];
}
// end addition

// forsplit

- (void) setTextView: (id)aView
{
    NSRange		theRange;
//  NSLayoutManager	*layoutManager;
    
    textView = aView;
    if (textView == textView1) {
        // Koch: June 20, 2003:
        // WARNING: This strange code fixes a bug when syntax coloring is on/
        // When the bug is active and the return key is pressed on an empty line,
        // the first nonempty line below it scrolls down, but remaining lines take a second
        // to catch up. Strangely, in splitscreen mode, this only affected the top half.
        // The bottom half scrolled immediately, and typing in the bottom screen scrolled
        // both halves immediately. Explain that.
     //   layoutManager = [textView1 layoutManager];
     //   [textStorage removeLayoutManager:layoutManager];
     //   [textStorage addLayoutManager:layoutManager];
        theRange = [textView2 selectedRange];
        theRange.length = 0;
        [textView2 setSelectedRange: theRange];
        }
    else {
     //   layoutManager = [textView2 layoutManager];
    //    [textStorage removeLayoutManager:layoutManager];
    //    [textStorage addLayoutManager:layoutManager];
        theRange = [textView1 selectedRange];
        theRange.length = 0;
        [textView1 setSelectedRange: theRange];
        }
}

// The next three methods implement the encoding button in the save panel

- (void) chooseEncoding: sender;
{
    tempencoding = [[sender selectedCell] tag];
}

- (void)runModalSavePanelForSaveOperation:(NSSaveOperationType)saveOperation delegate:(id)delegate didSaveSelector:(SEL)didSaveSelector contextInfo:(void *)contextInfo
{
    tempencoding = encoding;
    [super runModalSavePanelForSaveOperation:saveOperation delegate:delegate didSaveSelector:didSaveSelector contextInfo:contextInfo];
}

/*
-(void)document:(NSDocument *)doc didSave:(BOOL)didSave contextInfo:(void *)contextInfo
 {
    if ((didSave) && (encoding != tempencoding))
        NSRunAlertPanel(nil, nil, nil, NSLocalizedString(@"Cancel", @"Cancel"), 
                    textWindow, self, @selector(encodingSheetEnd:returnCode:contextInfo:), NULL, nil, 
                    NSLocalizedString(@"The file encoding changed; characters can be lost if the wrong encoding is used.",
            @"The file encoding changed; characters can be lost if the wrong encoding is used."));
 }
 
 -(void)encodingSheetEnd:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo
{
   switch(returnCode) {
   
    case NSAlertDefaultReturn:
        encodingChangeOK = YES;
        break;
        
    case NSAlertAlternateReturn: // cancel
        encodingChangeOK = NO;
        break;
        
    case NSAlertOtherReturn:
        encodingChangeOK = NO;
        break;
    }
}

*/
 
- (void)saveToFile:(NSString *)fileName saveOperation:(NSSaveOperationType)saveOperation delegate:(id)delegate didSaveSelector:(SEL)didSaveSelector contextInfo:(void *)contextInfo
{
        if (fileName != nil)
            encoding = tempencoding;
        [super saveToFile: fileName saveOperation: saveOperation delegate: delegate didSaveSelector: didSaveSelector contextInfo: contextInfo];
}


- (BOOL)prepareSavePanel:(NSSavePanel *)savePanel;
{
    NSView	*accessoryView;
    
    [openSaveBox selectItemAtIndex: encoding];
    accessoryView = [savePanel accessoryView];
    [openSaveView retain];
    NSEnumerator *enumerator = [[accessoryView subviews] objectEnumerator];
    id	anObject;
    while (anObject = [enumerator nextObject])
        [openSaveView addSubview: anObject];
    [savePanel setAccessoryView: openSaveView];
    return YES;
}

- (void) splitWindow: sender;
{
    NSSize		newSize;
    NSRect		theFrame;
    NSRange		selectedRange;
    
    selectedRange = [textView selectedRange];
    newSize.width = 100;
    newSize.height = 100;
    if (windowIsSplit) {
        [scrollView2 retain];
        [scrollView2 removeFromSuperview];
        windowIsSplit = NO;
        textView = textView1;
        [textView scrollRangeToVisible: selectedRange];
        [textView setSelectedRange: selectedRange];
        }
    else {
        theFrame = [scrollView frame];
        newSize.width = theFrame.size.width;
        newSize.height = 100;
        [scrollView setFrameSize:newSize];
        [scrollView2 setFrameSize:newSize];
        [splitView addSubview: scrollView2];
        [splitView adjustSubviews];
        [textView1 scrollRangeToVisible: selectedRange];
        [textView2 scrollRangeToVisible: selectedRange];
        selectedRange.length = 0;
        [textView2 setSelectedRange: selectedRange];

/*        
        sourceRange.location = 0;
        sourceRange.length = [[textView string] length];
        destRange.location = 0;
        destRange.length = [[textView2 string] length];
        myAttribString = [[[NSAttributedString alloc] initWithAttributedString:[textView attributedSubstringFromRange: sourceRange]] autorelease];
        [[textView2 textStorage] replaceCharactersInRange:destRange withAttributedString:myAttribString];
*/
 //     [textView2 setString: [textView string]];
    
//      [textView2 setTextContainer: [textView textContainer]];
        windowIsSplit = YES;
        textView = textView1;
        }
}


// endforsplit



/* A user reported that while working with an external editor, he quit TeXShop and was
asked if he wanted to save documents. When he did, the source file was replaced with an
empty file. He had used Page Setup, which marked the file as changed. The code below
insures that files opened with an external editor are never marked as changed. 
WARNING: This causes stack problems if the undo manager is enabled, so it is disabled
in other code when an external editor is being used. */

- (BOOL)isDocumentEdited
{
    if (externalEditor)
        return NO;
    else
        return [super isDocumentEdited];
}


//-----------------------------------------------------------------------------
- (void)registerForNotifications
//-----------------------------------------------------------------------------
/*" This method registers all notifications that are necessary to work properly together with the other AppKit and TeXShop objects.
"*/
{
    // register to learn when the document window becomes main so we can fix the Typeset script
    
    [[NSNotificationCenter defaultCenter] addObserver: self selector:@selector(newMainWindow:)
        name:NSWindowDidBecomeMainNotification object:nil];
                
    // register for notifications when the document window becomes key so we can remember which window was
    // the frontmost. This is needed for the preferences.
    [[NSNotificationCenter defaultCenter] addObserver:[TSWindowManager sharedInstance] selector:@selector(documentWindowDidBecomeKey:) name:NSWindowDidBecomeKeyNotification object:textWindow];
    [[NSNotificationCenter defaultCenter] addObserver:[Autrecontroller sharedInstance] selector:@selector(documentWindowDidBecomeKey:) name:NSWindowDidBecomeKeyNotification object:textWindow];
    [[NSNotificationCenter defaultCenter] addObserver:[TSWindowManager sharedInstance] selector:@selector(documentWindowWillClose:) name:NSWindowWillCloseNotification object:textWindow];
// added by mitsu --(J+) check mark in "Typeset" menu
    [[NSNotificationCenter defaultCenter] addObserver:[TSWindowManager sharedInstance] selector:@selector(documentWindowDidResignKey:) name:NSWindowDidResignKeyNotification object:textWindow];
// end addition 


    // register for notifications when the pdf window becomes key so we can remember which window was the frontmost.
    [[NSNotificationCenter defaultCenter] addObserver:[TSWindowManager sharedInstance] selector:@selector(pdfWindowDidBecomeKey:) name:NSWindowDidBecomeKeyNotification object:pdfWindow];
    [[NSNotificationCenter defaultCenter] addObserver:[Autrecontroller sharedInstance] selector:@selector(pdfWindowDidBecomeKey:) name:NSWindowDidBecomeKeyNotification object:pdfWindow];
    [[NSNotificationCenter defaultCenter] addObserver:[TSWindowManager sharedInstance] selector:@selector(pdfWindowWillClose:) name:NSWindowWillCloseNotification object:pdfWindow];
// added by mitsu --(J+) check mark in "Typeset" menu
    [[NSNotificationCenter defaultCenter] addObserver:[TSWindowManager sharedInstance] selector:@selector(pdfWindowDidResignKey:) name:NSWindowDidResignKeyNotification object:pdfWindow];
// end addition 

    
    // register for notification when the document font changes in preferences
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(setDocumentFontFromPreferences:) name:DocumentFontChangedNotification object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(revertDocumentFont:) name:DocumentFontRevertNotification object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(rememberFont:) name:DocumentFontRememberNotification object:nil];
    
    // register for notification when the syntax coloring changes in preferences
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(reColor:) name:DocumentSyntaxColorNotification object:nil];
    
    // register for notification when auto completion changes in preferences
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(changePrefAutoComplete:) name:DocumentAutoCompleteNotification object:nil];
    
    // externalEditChange
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(ExternalEditorChange:) name:ExternalEditorNotification object:nil];
    
    // notifications for pdftex and pdflatex
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(checkATaskStatus:) 
        name:NSTaskDidTerminateNotification object:nil];
        
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(checkPrefClose:) 
        name:NSWindowWillCloseNotification object:nil];
        
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(writeTexOutput:)
        name:NSFileHandleReadCompletionNotification object:nil];
        
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(doCompletion:)
        name:@"completionpanel" object:nil];
        
// added by mitsu --(D) reset tags when the encoding is switched
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(resetTagsMenu:) 
		name:@"ResetTagsMenuNotification" object:nil];

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(resetMacroButton:) 
		name:@"ResetMacroButtonNotification" object:nil];
// end addition

    [[NSNotificationCenter defaultCenter] addObserver:self
        selector:@selector(resetTagsMenu:)
        name:@"NSUndoManagerDidRedoChangeNotification" object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
        selector:@selector(resetTagsMenu:)
        name:@"NSUndoManagerDidUndoChangeNotification" object:nil];


}

//-----------------------------------------------------------------------------
- (void)setupFromPreferencesUsingWindowController:(NSWindowController *)windowController
//-----------------------------------------------------------------------------
/*" This method reads the NSUserDefaults and restores the settings before the document will actually be displayed.
"*/
{
    // inhibit ordering of windows by windowController.
    [windowController setShouldCascadeWindows:NO];

    // restore window position for the document window
    switch ([SUD integerForKey:DocumentWindowPosModeKey])
    {
        case DocumentWindowPosSave:
            [textWindow setFrameAutosaveName:DocumentWindowNameKey];
            break;
            
        case DocumentWindowPosFixed:
            [textWindow setFrameFromString:[SUD stringForKey:DocumentWindowFixedPosKey]];
            break;
    }
    
    // restore window position for the pdf window
    switch ([SUD integerForKey:PdfWindowPosModeKey])
    {
        case PdfWindowPosSave:
            [pdfWindow setFrameAutosaveName:PdfWindowNameKey];
            break;
            
        case PdfWindowPosFixed:
            [pdfWindow setFrameFromString:[SUD stringForKey:PdfWindowFixedPosKey]];
    }
    
	// restore the font for document if desired
	if ([SUD boolForKey:SaveDocumentFontKey] == YES)
    {
        [self setDocumentFontFromPreferences:nil];
	}

/*
    // setup the popUp with all of our template names
    [popupButton addItemsWithTitles:[[TSPreferences sharedInstance] allTemplateNames]];
*/

    // new template menu (by S. Zenitani, Jan 31, 2003)
    NSFileManager *fm;
    NSString      *basePath, *path, *title;
    NSArray       *fileList;
    NSMenuItem	  *newItem;
    NSMenu 	  *submenu;
    BOOL	   isDirectory;
    unsigned i;
    unsigned lv = 3;
    
    fm       = [ NSFileManager defaultManager ];
    basePath = [ TexTemplatePathKey stringByStandardizingPath ];
    fileList = [ fm directoryContentsAtPath: basePath ];

    for( i=0; i<[fileList count]; i++ ) {
        title = [ fileList objectAtIndex: i ];
        path  = [ basePath stringByAppendingPathComponent: title ];
        if( [fm fileExistsAtPath:path isDirectory: &isDirectory] ){
            if( isDirectory ){
                [popupButton addItemWithTitle: @""];
                newItem = [popupButton lastItem];
                [newItem setTitle: title];
                submenu = [[[NSMenu alloc] init] autorelease];
                [self makeMenuFromDirectory: submenu basePath: path
                    action: @selector(doTemplate:) level: lv];
                [newItem setSubmenu: submenu];
            }else if ( [ [[title pathExtension] lowercaseString] isEqualToString: @"tex"] ) {
                title = [title stringByDeletingPathExtension];
                [popupButton addItemWithTitle: @""];
                newItem = [popupButton lastItem];
                [newItem setTitle: title];
                // begin addition
                [newItem setAction: @selector(doTemplate:)];
		[newItem setTarget: self];
                [newItem setRepresentedObject: path];
                // end addition

            }
        }
    }
    // end of addition
}

//-----------------------------------------------------------------------------
- (void) makeMenuFromDirectory: (NSMenu *)menu basePath: (NSString *)basePath action:(SEL)action level:(unsigned)level;
//-----------------------------------------------------------------------------
/* build a submenu from the specified directory (by S. Zenitani, Jan 31, 2003) */
{
    NSFileManager *fm;
    NSArray       *fileList;
    NSString      *path, *title;
    NSMenuItem	  *newItem;
    NSMenu 	  *submenu;
    BOOL	   isDirectory;
    unsigned i;

    level--;
    fm       = [ NSFileManager defaultManager ];
    fileList = [ fm directoryContentsAtPath: basePath ];

    for( i=0; i<[fileList count]; i++ ) {
        title = [ fileList objectAtIndex: i ];
        path  = [ basePath stringByAppendingPathComponent: title ];
        if( [fm fileExistsAtPath:path isDirectory: &isDirectory] ){
            if( isDirectory ){
                newItem=[menu addItemWithTitle: title action: nil keyEquivalent: @""];
                if( level > 0 ){
                    submenu = [[[NSMenu alloc] init] autorelease];
                    [self makeMenuFromDirectory: submenu basePath: path
                            action: action level: level];
                    [newItem setSubmenu: submenu];
                }
            }else if ([[[title pathExtension] lowercaseString] isEqualToString: @"tex"]) {
                title = [title stringByDeletingPathExtension];
                newItem = [menu addItemWithTitle: title action: action keyEquivalent: @""];
                [newItem setTarget: self];
                [newItem setRepresentedObject: path];
            }
        }
    }
}

//-----------------------------------------------------------------------------
- (void)setDocumentFontFromPreferences:(NSNotification *)notification
//-----------------------------------------------------------------------------
/*" Changes the font of %textView to the one saved in the NSUserDefaults. This method is also registered with NSNotificationCenter and a notifictaion will be send whenever the font changes in the preferences panel.
"*/
{
	NSData	*fontData;
	NSFont 	*font;
        
	fontData = [SUD objectForKey:DocumentFontKey];
	if (fontData != nil)
	{
		font = [NSUnarchiver unarchiveObjectWithData:fontData];
		[textView setFont:font];
	}
        [self fixUpTabs];
}

- (void)ExternalEditorChange:(NSNotification *)notification
{
    [[[NSApplication sharedApplication] delegate] configureExternalEditor];
}


- (BOOL) externalEditor
{
    return (externalEditor);
}

//-----------------------------------------------------------------------------
- (void)rememberFont:(NSNotification *)notification
//-----------------------------------------------------------------------------
/*" Called when preferences starts to save current font "*/
{
	NSFont 	*font;
        
	if (previousFontData != nil)
            [previousFontData release];
	{
		font = [textView font];
		previousFontData = [[NSArchiver archivedDataWithRootObject: font] retain];
	}
}

//-----------------------------------------------------------------------------
- (void)revertDocumentFont:(NSNotification *)notification
//-----------------------------------------------------------------------------
/*" Changes the font of %textView to the one used before preferences called, in case the
preference change is cancelled. "*/
{
	NSFont 	*font;
        
	if (previousFontData != nil)
	{
		font = [NSUnarchiver unarchiveObjectWithData:previousFontData];
		[textView setFont:font];
	}
        [self fixUpTabs];
}

    
- (void)close
{
    if (syntaxColoringTimer != nil) 
    {
        [syntaxColoringTimer invalidate];
        [syntaxColoringTimer release];
        syntaxColoringTimer = nil;
    }
    
    if (tagTimer != nil) 
    {
        [tagTimer invalidate];
        [tagTimer release];
        tagTimer = nil;
    }
    [pdfWindow close];
    /* The next line fixes a crash bug in Jaguar; see closeActiveDocument for
    a description. */
    [[TSWindowManager sharedInstance] closeActiveDocument];
    	
    // mitsu 1.29 (P)
    if (!fileIsTex && [[self fileName] isEqualToString: 
            [CommandCompletionPathKey stringByStandardizingPath]])
        canRegisterCommandCompletion = YES;
    // end mitsu 1.29

    [super close];
}

//-----------------------------------------------------------------------------
- (void) doNothing: (id) theDictionary;
//-----------------------------------------------------------------------------
{
    ;
}

- (NSData *)dataRepresentationOfType:(NSString *)aType {

    NSStringEncoding	theEncoding;
    // Insert code here to write your document from the given data.

//    NSUndoManager		*myManager;
//    NSNotificationCenter	*myCenter;
    
//    myManager = [textView undoManager];
//    myCenter = [NSNotificationCenter defaultCenter];
//    [myCenter postNotificationName: @"NSUndoManagerCheckpointNotification" object: myManager];
    
    
//    [myManager beginUndoGrouping];
//    [myManager endUndoGrouping];
//    [myManager registerUndoWithTarget: scrollView selector:@selector(fake:) object: nil];
//    [myManager removeAllActionsWithTarget: scrollView];  
//    [myManager removeAllActions];
    
/*

    myManager = [textView undoManager];
    [myManager endUndoGrouping];
*/    
    
    
    
    
    // The following is line has been changed to fix the bug from Geoff Leyland 
    // return [[textView string] dataUsingEncoding: NSASCIIStringEncoding];
    
   theEncoding = [[EncodingSupport sharedInstance] stringEncodingForTag: encoding];
   return [[textView string] dataUsingEncoding: theEncoding allowLossyConversion:YES];
    
/*    
    if([[SUD stringForKey:EncodingKey] isEqualToString:@"MacOSRoman"])
        return [[textView string] dataUsingEncoding: NSMacOSRomanStringEncoding allowLossyConversion:YES];
    else if([[SUD stringForKey:EncodingKey] isEqualToString:@"IsoLatin"])
        return [[textView string] dataUsingEncoding: NSISOLatin1StringEncoding allowLossyConversion:YES];
    else if([[SUD stringForKey:EncodingKey] isEqualToString:@"IsoLatin2"])
        return [[textView string] dataUsingEncoding: NSISOLatin2StringEncoding allowLossyConversion:YES];
    else if([[SUD stringForKey:EncodingKey] isEqualToString:@"MacJapanese"]) 
        return [[textView string] dataUsingEncoding: CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingMacJapanese) allowLossyConversion:YES];
     // S. Zenitani Dec 13, 2002:
    else if([[SUD stringForKey:EncodingKey] isEqualToString:@"DOSJapanese"]) 
        return [[textView string] dataUsingEncoding: CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingDOSJapanese) allowLossyConversion:YES];
    else if([[SUD stringForKey:EncodingKey] isEqualToString:@"EUC_JP"]) 
        return [[textView string] dataUsingEncoding: CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingEUC_JP) allowLossyConversion:YES];
    // --- end
     else if([[SUD stringForKey:EncodingKey] isEqualToString:@"JISJapanese"]) 
        return [[textView string] dataUsingEncoding: CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingISO_2022_JP) allowLossyConversion:YES];
    else if([[SUD stringForKey:EncodingKey] isEqualToString:@"MacKorean"]) 
        return [[textView string] dataUsingEncoding: CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingMacKorean) allowLossyConversion:YES];
    else if([[SUD stringForKey:EncodingKey] isEqualToString:@"UTF-8 Unicode"]) 
        return [[textView string] dataUsingEncoding: NSUTF8StringEncoding allowLossyConversion:YES];
    else if([[SUD stringForKey:EncodingKey] isEqualToString:@"Standard Unicode"])
        return [[textView string] dataUsingEncoding: NSUnicodeStringEncoding allowLossyConversion:YES];
    else if([[SUD stringForKey:EncodingKey] isEqualToString:@"Mac Cyrillic"]) 
        return [[textView string] dataUsingEncoding: CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingMacCyrillic) allowLossyConversion:YES];
    else if([[SUD stringForKey:EncodingKey] isEqualToString:@"DOS Cyrillic"]) 
        return [[textView string] dataUsingEncoding: CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingDOSCyrillic) allowLossyConversion:YES];
    else if([[SUD stringForKey:EncodingKey] isEqualToString:@"DOS Russian"]) 
        return [[textView string] dataUsingEncoding: CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingDOSRussian) allowLossyConversion:YES];
    else if([[SUD stringForKey:EncodingKey] isEqualToString:@"Windows Cyrillic"]) 
        return [[textView string] dataUsingEncoding: CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingWindowsCyrillic) allowLossyConversion:YES];
    else if([[SUD stringForKey:EncodingKey] isEqualToString:@"KOI8_R"]) 
        return [[textView string] dataUsingEncoding: CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingKOI8_R) allowLossyConversion:YES];
    else 
         return [[textView string] dataUsingEncoding: NSMacOSRomanStringEncoding allowLossyConversion:YES];
*/
}



- (BOOL)readFromFile:(NSString *)fileName ofType:(NSString *)type {
    int			tag;
    id 			myData;
    NSStringEncoding	theEncoding;
    
//    tag = [[EncodingSupport sharedInstance] tagForEncodingPreference];
    tag = encoding;
    theEncoding = [[EncodingSupport sharedInstance] stringEncodingForTag: tag];
    myData = [NSData dataWithContentsOfFile:fileName];
    aString = [[[NSString alloc] initWithData:myData encoding:theEncoding] autorelease];
    return YES;
    
/*    
    if([[SUD stringForKey:EncodingKey] isEqualToString:@"MacOSRoman"])
        aString = [[NSString stringWithContentsOfFile:fileName] retain];
    else if ([[SUD stringForKey:EncodingKey] isEqualToString:@"IsoLatin"]) {
        myData = [NSData dataWithContentsOfFile:fileName];
        aString = [[[NSString alloc] initWithData:myData encoding: NSISOLatin1StringEncoding] retain];
        }
    else if ([[SUD stringForKey:EncodingKey] isEqualToString:@"IsoLatin2"]) {
        myData = [NSData dataWithContentsOfFile:fileName];
        aString = [[[NSString alloc] initWithData:myData encoding: NSISOLatin2StringEncoding] retain];
        }
     else if ([[SUD stringForKey:EncodingKey] isEqualToString:@"MacJapanese"]) {
        myData = [NSData dataWithContentsOfFile:fileName];
        aString = [[[NSString alloc] initWithData:myData encoding: CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingMacJapanese)] retain];
        }
    // S. Zenitani Dec 13, 2002:
    else if ([[SUD stringForKey:EncodingKey] isEqualToString:@"DOSJapanese"]) {
        myData = [NSData dataWithContentsOfFile:fileName];
        aString = [[[NSString alloc] initWithData:myData encoding: CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingDOSJapanese)] retain];
        }
     else if ([[SUD stringForKey:EncodingKey] isEqualToString:@"EUC_JP"]) {
        myData = [NSData dataWithContentsOfFile:fileName];
        aString = [[[NSString alloc] initWithData:myData encoding: CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingEUC_JP)] retain];
        }
    // --- end
     else if ([[SUD stringForKey:EncodingKey] isEqualToString:@"JISJapanese"]) {
        myData = [NSData dataWithContentsOfFile:fileName];
        aString = [[[NSString alloc] initWithData:myData encoding: CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingISO_2022_JP)] retain];
        }
    else if ([[SUD stringForKey:EncodingKey] isEqualToString:@"MacKorean"]) {
        myData = [NSData dataWithContentsOfFile:fileName];
        aString = [[[NSString alloc] initWithData:myData encoding: CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingMacKorean)] retain];
        }
    else if ([[SUD stringForKey:EncodingKey] isEqualToString:@"UTF-8 Unicode"]) {
        myData = [NSData dataWithContentsOfFile:fileName];
        aString = [[[NSString alloc] initWithData:myData encoding: NSUTF8StringEncoding] retain];
        }
    else if ([[SUD stringForKey:EncodingKey] isEqualToString:@"Standard Unicode"]) {
        myData = [NSData dataWithContentsOfFile:fileName];
        aString = [[[NSString alloc] initWithData:myData encoding: NSUnicodeStringEncoding] retain];
        }
     else if ([[SUD stringForKey:EncodingKey] isEqualToString:@"Mac Cyrillic"]) {
        myData = [NSData dataWithContentsOfFile:fileName];
        aString = [[[NSString alloc] initWithData:myData encoding: CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingMacCyrillic)] retain];
        }
     else if ([[SUD stringForKey:EncodingKey] isEqualToString:@"DOS Cyrillic"]) {
        myData = [NSData dataWithContentsOfFile:fileName];
        aString = [[[NSString alloc] initWithData:myData encoding: CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingDOSCyrillic)] retain];
        }
     else if ([[SUD stringForKey:EncodingKey] isEqualToString:@"DOS Russian"]) {
        myData = [NSData dataWithContentsOfFile:fileName];
        aString = [[[NSString alloc] initWithData:myData encoding: CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingDOSRussian)] retain];
        }
     else if ([[SUD stringForKey:EncodingKey] isEqualToString:@"Windows Cyrillic"]) {
        myData = [NSData dataWithContentsOfFile:fileName];
        aString = [[[NSString alloc] initWithData:myData encoding: CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingWindowsCyrillic)] retain];
        }
     else if ([[SUD stringForKey:EncodingKey] isEqualToString:@"KOI8_R"]) {
        myData = [NSData dataWithContentsOfFile:fileName];
        aString = [[[NSString alloc] initWithData:myData encoding: CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingKOI8_R)] retain];
        }
    else
        aString = [[NSString stringWithContentsOfFile:fileName] retain];
    return YES;
*/
}

// The default save operations clear the "document edited symbol" but
// do not reset the undo stack, and then later the symbol gets out of sync.
// This seems like a bug; it is fixed by the code below. RMK: 6/22/01 

// On December 30, 2002, Max Horn complained about this fix. I removed it,
// and things seem to be fine. So for now I'll stick with eliminating the
// fix!

// On January 10, 2003, I reimplemented the code, because the December fix
// produced the original "out of sync" bugs. In particular, the program would
// quit without asking if it should save changed files!

- (BOOL)writeToFile:(NSString *)fileName ofType:(NSString *)docType
{
    BOOL		result;
    NSUndoManager	*myManager;

    result = [super writeToFile:fileName ofType:docType];
    if (result) {
//      [[textView undoManager] removeAllActions];
         myManager = [self undoManager];
        [myManager registerUndoWithTarget:self selector:@selector(doNothing:) object: nil];
        [myManager setActionName:NSLocalizedString(@"Save Spot", @"Save Spot")];
        [[textWindow undoManager] undo];
        }
    return result;
}

- (BOOL)keepBackupFile
{
    return [SUD boolForKey:KeepBackupKey];
}

- (id) magnificationPanel;
{
    return magnificationPanel;
}

- (id) pagenumberPanel;
{
    return pagenumberPanel;
}

- (void) quitMagnificationPanel: sender;
{
    [NSApp endSheet: magnificationPanel returnCode: 0];
}

- (void)quitPagenumberPanel: sender;
{
    [NSApp endSheet: pagenumberPanel returnCode: 0];
}

//-----------------------------------------------------------------------------
- (void) fixTemplate: (id) theDictionary;
//-----------------------------------------------------------------------------

{
    NSRange		oldRange;
    NSString		*oldString, *newString;
    NSUndoManager	*myManager;
    NSMutableDictionary	*myDictionary;
    NSNumber		*theLocation, *theLength;
    unsigned		from, to;
    
    oldRange.location = [[theDictionary objectForKey: @"oldLocation"] unsignedIntValue];
    oldRange.length = [[theDictionary objectForKey: @"oldLength"] unsignedIntValue];
    newString = [theDictionary objectForKey: @"oldString"];
    oldString = [[textView string] substringWithRange: oldRange];
    [textView replaceCharactersInRange: oldRange withString: newString];

    myManager = [textView undoManager];
    myDictionary = [NSMutableDictionary dictionaryWithCapacity: 3];
    theLocation = [NSNumber numberWithInt: oldRange.location];
    theLength = [NSNumber numberWithInt: [newString length]];
    [myDictionary setObject: oldString forKey: @"oldString"];
    [myDictionary setObject: theLocation forKey: @"oldLocation"];
    [myDictionary setObject: theLength forKey: @"oldLength"];
    [myManager registerUndoWithTarget:self selector:@selector(fixTemplate:) object: myDictionary];
    [myManager setActionName:NSLocalizedString(@"Template", @"Template")];
    from = oldRange.location;
    to = from + [newString length];
    [self fixColor: from :to];
    [self setupTags];

}

/* This code was modified by Martin Heusse; see below
//-----------------------------------------------------------------------------
- (void) doTemplate: sender 
//-----------------------------------------------------------------------------
{
    NSString		*templateString, *nameString, *oldString;
    id			theItem;
    id			myData;
    unsigned		from, to;
    NSRange		myRange;
    NSUndoManager	*myManager;
    NSMutableDictionary	*myDictionary;
    NSNumber		*theLocation, *theLength;
    
    theItem = [sender selectedItem];
    if (theItem != nil) 
    {
        nameString = [TexTemplatePathKey stringByStandardizingPath];
        nameString = [nameString stringByAppendingPathComponent:[theItem title]];
        nameString = [nameString stringByAppendingPathExtension:@"tex"];
        
        if([[SUD stringForKey:EncodingKey] isEqualToString:@"MacOSRoman"])
            templateString = [NSString stringWithContentsOfFile:nameString];
        else if ([[SUD stringForKey:EncodingKey] isEqualToString:@"IsoLatin"]) {
            myData = [NSData dataWithContentsOfFile:nameString];
            templateString = [[NSString alloc] initWithData:myData 
                encoding: NSISOLatin1StringEncoding];
            }
        else if ([[SUD stringForKey:EncodingKey] isEqualToString:@"MacJapanese"]) {
            myData = [NSData dataWithContentsOfFile:nameString];
            templateString = [[NSString alloc] initWithData:myData 
            encoding: CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingMacJapanese)];         	   }
        else if ([[SUD stringForKey:EncodingKey] isEqualToString:@"MacKorean"]) {
            myData = [NSData dataWithContentsOfFile:nameString];
            templateString = [[NSString alloc] initWithData:myData 
            encoding: CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingMacKorean)];
            }
        else
            templateString = [NSString stringWithContentsOfFile:nameString];

        if (templateString != nil) 
        {
            myRange = [textView selectedRange];
            oldString = [[textView string] substringWithRange: myRange];
            [textView replaceCharactersInRange:myRange withString:templateString];
            
            myManager = [textView undoManager];
            myDictionary = [NSMutableDictionary dictionaryWithCapacity: 3];
            theLocation = [NSNumber numberWithUnsignedInt: myRange.location];
            theLength = [NSNumber numberWithUnsignedInt: [templateString length]];
            [myDictionary setObject: oldString forKey: @"oldString"];
            [myDictionary setObject: theLocation forKey: @"oldLocation"];
            [myDictionary setObject: theLength forKey: @"oldLength"];
            [myManager registerUndoWithTarget:self selector:@selector(fixTemplate:) object: myDictionary];
            [myManager setActionName:@"Template"];

            from = myRange.location;
            to = from + [templateString length];
            [self fixColor:from :to];
            [self setupTags];
        }
    }
}
*/

// Modified by Martin Heusse
// Modified by Seiji Zenitani (Jan 31, 2003)
//==================================================================
- (void) doTemplate: sender
//-----------------------------------------------------------------------------
{
    NSString		*nameString, *oldString;
    id			theItem;
    unsigned		from, to;
    NSRange		myRange;
    NSUndoManager	*myManager;
    NSMutableDictionary	*myDictionary;
    NSNumber		*theLocation, *theLength;
    id			myData;
    NSStringEncoding	theEncoding;
    int			tag;
    
    NSRange 		NewlineRange;
    int 		i, numTabs, numSpaces=0;
    NSMutableString	*templateString, *indentString = [NSMutableString stringWithString:@"\n"];

/*
    theItem = [sender selectedItem];
*/
    // for submenu items
    if ([sender isKindOfClass: [NSMenuItem class]])
    {
        nameString = [(NSMenuItem *)sender representedObject];
    }
    // for popup button
    else
    {
        theItem = [sender selectedItem];
        if ( theItem != nil ){
            nameString = [TexTemplatePathKey stringByStandardizingPath];
            nameString = [nameString stringByAppendingPathComponent:[theItem title]];
            nameString = [nameString stringByAppendingPathExtension:@"tex"];
        }else{
            return;
        }
    }

    // if ( theItem != nil )
    if ( [[NSFileManager defaultManager] fileExistsAtPath: nameString] )
    {
/*
        // The lines are moved (S. Zenitani, Jan 31, 2003)
        nameString = [TexTemplatePathKey stringByStandardizingPath];
        nameString = [nameString stringByAppendingPathComponent:[theItem title]];
        nameString = [nameString stringByAppendingPathExtension:@"tex"];
*/
        tag = [[EncodingSupport sharedInstance] tagForEncodingPreference];
        theEncoding = [[EncodingSupport sharedInstance] stringEncodingForTag: tag];
        myData = [NSData dataWithContentsOfFile:nameString];
        templateString = [[[NSMutableString alloc] initWithData:myData encoding:theEncoding] autorelease];


/*
        if([[SUD stringForKey:EncodingKey] isEqualToString:@"MacOSRoman"])
            templateString = [NSMutableString stringWithContentsOfFile:nameString];
        else if ([[SUD stringForKey:EncodingKey] isEqualToString:@"IsoLatin"]) {
            myData = [NSData dataWithContentsOfFile:nameString];
            templateString = [[NSMutableString alloc] initWithData:myData
                                                   encoding: NSISOLatin1StringEncoding];
        }
        else if ([[SUD stringForKey:EncodingKey] isEqualToString:@"IsoLatin2"]) {
            myData = [NSData dataWithContentsOfFile:nameString];
            templateString = [[NSMutableString alloc] initWithData:myData
                                                   encoding: NSISOLatin2StringEncoding];
        }
        else if ([[SUD stringForKey:EncodingKey] isEqualToString:@"MacJapanese"]) {
            myData = [NSData dataWithContentsOfFile:nameString];
            templateString = [[NSMutableString alloc] initWithData:myData
                                                   encoding: CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingMacJapanese)];         	   }
         // S. Zenitani Dec 13, 2002:
        else if ([[SUD stringForKey:EncodingKey] isEqualToString:@"DOSJapanese"]) {
            myData = [NSData dataWithContentsOfFile:nameString];
            templateString = [[NSMutableString alloc] initWithData:myData
                                                   encoding: CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingDOSJapanese)];         	   }
        else if ([[SUD stringForKey:EncodingKey] isEqualToString:@"EUC_JP"]) {
            myData = [NSData dataWithContentsOfFile:nameString];
            templateString = [[NSMutableString alloc] initWithData:myData
                                                   encoding: CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingEUC_JP)];         	   }
        // --- end
        else if ([[SUD stringForKey:EncodingKey] isEqualToString:@"JISJapanese"]) {
            myData = [NSData dataWithContentsOfFile:nameString];
            templateString = [[NSMutableString alloc] initWithData:myData
                                                   encoding: CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingISO_2022_JP)];         	   }
        else if ([[SUD stringForKey:EncodingKey] isEqualToString:@"MacKorean"]) {
            myData = [NSData dataWithContentsOfFile:nameString];
            templateString = [[NSMutableString alloc] initWithData:myData
                                                   encoding: CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingMacKorean)];
        }
        else if ([[SUD stringForKey:EncodingKey] isEqualToString:@"UTF-8 Unicode"]) {
            myData = [NSData dataWithContentsOfFile:nameString];
            templateString = [[NSMutableString alloc] initWithData:myData
                                                   encoding: NSUTF8StringEncoding];
        }
        else if ([[SUD stringForKey:EncodingKey] isEqualToString:@"Standard Unicode"]) {
            myData = [NSData dataWithContentsOfFile:nameString];
            templateString = [[NSMutableString alloc] initWithData:myData
                                                   encoding: NSUnicodeStringEncoding];
        }
        else if ([[SUD stringForKey:EncodingKey] isEqualToString:@"Mac Cyrillic"]) {
            myData = [NSData dataWithContentsOfFile:nameString];
            templateString = [[NSMutableString alloc] initWithData:myData
                                                   encoding: CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingMacCyrillic)];
        }
        else if ([[SUD stringForKey:EncodingKey] isEqualToString:@"DOS Cyrillic"]) {
            myData = [NSData dataWithContentsOfFile:nameString];
            templateString = [[NSMutableString alloc] initWithData:myData
                                                   encoding: CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingDOSCyrillic)];
        }
        else if ([[SUD stringForKey:EncodingKey] isEqualToString:@"DOS Russian"]) {
            myData = [NSData dataWithContentsOfFile:nameString];
            templateString = [[NSMutableString alloc] initWithData:myData
                                                   encoding: CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingDOSRussian)];
        }
        else if ([[SUD stringForKey:EncodingKey] isEqualToString:@"Windows Cyrillic"]) {
            myData = [NSData dataWithContentsOfFile:nameString];
            templateString = [[NSMutableString alloc] initWithData:myData
                                                   encoding: CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingWindowsCyrillic)];
        }
        else if ([[SUD stringForKey:EncodingKey] isEqualToString:@"KOI8_R"]) {
            myData = [NSData dataWithContentsOfFile:nameString];
            templateString = [[NSMutableString alloc] initWithData:myData
                                                   encoding: CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingKOI8_R)];
        }
        else
            templateString = [NSMutableString stringWithContentsOfFile:nameString];
*/

        // check and rebuild the trailing string...
        numTabs = [self textViewCountTabs:textView andSpaces:(int *)&numSpaces];
        for(i=0 ; i<numTabs ; i++) [indentString appendString:@"\t"];
        for(i=0 ; i<numSpaces ; i++) [indentString appendString:@" "];

        // modify the template string and add the tabs & spaces...
        NewlineRange = [templateString rangeOfString: @"\n"
                                             options: NSBackwardsSearch
                                               range: NSMakeRange(0,[templateString length])];
        while(NewlineRange.location > 0 && NewlineRange.location != NSNotFound){
            // NSLog(@"%d", NewlineRange.location);
            [templateString replaceCharactersInRange: NewlineRange withString: indentString];
            NewlineRange = [templateString rangeOfString:@"\n"
                                                 options: NSBackwardsSearch
                                                   range: NSMakeRange(0,NewlineRange.location)];
        }

        if (templateString != nil)
        {
            myRange = [textView selectedRange];
            oldString = [[textView string] substringWithRange: myRange];
            [textView replaceCharactersInRange:myRange withString:templateString];

            myManager = [textView undoManager];
            myDictionary = [NSMutableDictionary dictionaryWithCapacity: 3];
            theLocation = [NSNumber numberWithUnsignedInt: myRange.location];
            theLength = [NSNumber numberWithUnsignedInt: [templateString length]];
            [myDictionary setObject: oldString forKey: @"oldString"];
            [myDictionary setObject: theLocation forKey: @"oldLocation"];
            [myDictionary setObject: theLength forKey: @"oldLength"];
            [myManager registerUndoWithTarget:self selector:@selector(fixTemplate:) object: myDictionary];
             [myManager setActionName:NSLocalizedString(@"Template", @"Template")];

            from = myRange.location;
            to = from + [templateString length];
            [self fixColor:from :to];
            [self setupTags];
        }
    }
}


- (void) doJob:(int)type withError:(BOOL)error;
{
    SEL		saveFinished;
    NSDate	*myDate;
    
    if (! fileIsTex)
        return;
    
    /* The lines of code below kill previously running tasks. This is
    necessary because otherwise the source file will be open when the
    system tries to save a new version. If the source file is open,
    NSDocument makes a backup in /tmp which is never removed. */
    
    if (texTask != nil) {
                if (theScript == 101) {
                    kill( -[texTask processIdentifier], SIGTERM);
                    }
                else
                    [texTask terminate];
                myDate = [NSDate date];
                while (([texTask isRunning]) && ([myDate timeIntervalSinceDate:myDate] < 0.5)) ;
                [texTask release];
                texTask = nil;
            }
            
    if (bibTask != nil) {
                [bibTask terminate];
                myDate = [NSDate date];
                while (([bibTask isRunning]) && ([myDate timeIntervalSinceDate:myDate] < 0.5)) ;
                [bibTask release];
                bibTask = nil;
            }
            
    if (indexTask != nil) {
                [indexTask terminate];
                myDate = [NSDate date];
                while (([indexTask isRunning]) && ([myDate timeIntervalSinceDate:myDate] < 0.5)) ;
                [indexTask release];
                indexTask = nil;
            }
            
    if (metaFontTask != nil) {
                [metaFontTask terminate];
                myDate = [NSDate date];
                while (([metaFontTask isRunning]) && ([myDate timeIntervalSinceDate:myDate] < 0.5)) ;
                [metaFontTask release];
                metaFontTask = nil;
            }

    
    errorNumber = 0;
    whichError = 0;
    makeError = error;
    
   //  whichEngine = type;
   
// added by mitsu --(J+) check mark in "Typeset" menu
	[[TSWindowManager sharedInstance] checkProgramMenuItem: whichEngine checked: NO];
// end addition
    whichEngine = type;
// added by mitsu --(J+) check mark in "Typeset" menu
	[[TSWindowManager sharedInstance] checkProgramMenuItem: whichEngine checked: YES];
        [self fixMacroMenu];
// end addition

    if ((externalEditor) || (! [self isDocumentEdited])) {
        [self saveFinished: self didSave:YES contextInfo:nil];
        }
    else {
        saveFinished = @selector(saveFinished:didSave:contextInfo:);
        [self saveDocumentWithDelegate: self didSaveSelector: saveFinished contextInfo: nil];
        }
}


- (NSString *) separate: (NSString *)myEngine into:(NSMutableArray *)args;
{   
    NSArray		*myList;
    NSString		*myString, *middleString;
    int			size, i, pos;
    BOOL		programFound, inMiddle;
    NSString		*theEngine;
    NSRange		aRange;

    if (myEngine != nil) {
        myList = [myEngine componentsSeparatedByString:@" "];
        programFound = NO;
        inMiddle = NO;
        size = [myList count];
        i = 0;
        while (i < size) {
            myString = [myList objectAtIndex:i];
            if ((myString != nil) && ([myString length] > 0)) {
                if (! programFound) {
                    theEngine = myString;
                    programFound = YES;
                    }
                else if (inMiddle) {
                    middleString = [middleString stringByAppendingString:@" "];
                    middleString = [middleString stringByAppendingString:myString];
                    pos = [myString length] - 1;
                    if ([myString characterAtIndex:pos] == '"') {
                        aRange.location = 1;
                        aRange.length = [middleString length] - 2;
                        middleString = [middleString substringWithRange: aRange];
                        [args addObject: middleString];
                        inMiddle = NO;
                        }
                    }
                else if ([myString characterAtIndex:0] == '"') {
                    pos = [myString length] - 1;
                    if ([myString characterAtIndex:pos] == '"') {
                        aRange.location = 1;
                        aRange.length = [myString length] - 2;
                        myString = [myString substringWithRange: aRange];
                        [args addObject: myString];
                        }
                    else {
                        middleString = [NSString stringWithString: myString];
                        inMiddle = YES;
                        }
                    }
                else {
                    [args addObject: myString];
                    } 
                }
            i = i + 1;
            }
        if (! programFound)
            theEngine = nil;
        }
    
    return (theEngine);
}

- (void) convertDocument;
{
    NSString		*myFileName;
    NSMutableArray	*args;
    NSDictionary	*myAttributes;
    NSString		*imagePath;
    NSString		*sourcePath;
    NSString		*enginePath;
    NSString		*tetexBinPath;
    NSString		*epstopdfPath;
    
    myFileName = [self fileName];
    if ([myFileName length] > 0) {
            
        imagePath = [[[self fileName] stringByDeletingPathExtension] stringByAppendingPathExtension:@"pdf"];

        if ([[NSFileManager defaultManager] fileExistsAtPath: imagePath]) {
            myAttributes = [[NSFileManager defaultManager] fileAttributesAtPath: imagePath traverseLink:NO];
            startDate = [[myAttributes objectForKey:NSFileModificationDate] retain];
            }
        else
            startDate = nil;
    
        args = [NSMutableArray array];
        sourcePath = myFileName;
        
        texTask = [[NSTask alloc] init];
        [texTask setCurrentDirectoryPath: [sourcePath stringByDeletingLastPathComponent]];
        [texTask setEnvironment: TSEnvironment];
        
        if ([[myFileName pathExtension] isEqualToString:@"dvi"]) {
            enginePath = [SUD stringForKey:LatexGSCommandKey];
            enginePath = [self separate:enginePath into: args];
            if ([SUD boolForKey:SavePSEnabledKey])
            	[args addObject: [NSString stringWithString:@"--keep-psfile"]];
            }    
        else if ([[myFileName pathExtension] isEqualToString:@"ps"]) {
            enginePath = [[NSBundle mainBundle] pathForResource:@"ps2pdfwrap" ofType:nil];
            }
        else if  ([[myFileName pathExtension] isEqualToString:@"eps"]) {
            enginePath = [[NSBundle mainBundle] pathForResource:@"epstopdfwrap" ofType:nil];
            
            tetexBinPath = [[SUD stringForKey:TetexBinPathKey] stringByAppendingString:@"/"];
            epstopdfPath = [tetexBinPath stringByAppendingString:@"epstopdf"];
            // [args addObject: [[NSBundle mainBundle] pathForResource:@"epstopdf" ofType:nil]];
            [args addObject: epstopdfPath];
            }

        [args addObject: [sourcePath lastPathComponent]];

        if (enginePath != nil) {
            if ([enginePath characterAtIndex:0] != '/') {
                tetexBinPath = [[SUD stringForKey:TetexBinPathKey] stringByAppendingString:@"/"];
                enginePath = [tetexBinPath stringByAppendingString:enginePath];
                }
            }
        inputPipe = [[NSPipe pipe] retain];
        [texTask setStandardInput: inputPipe];
        if ((enginePath != nil) && ([[NSFileManager defaultManager] fileExistsAtPath: enginePath])) {
                [texTask setLaunchPath:enginePath];
                [texTask setArguments:args];
                [texTask launch];
        }
        else {
            [inputPipe release];
            [texTask release];
            texTask = nil;
        }
    }
}

- (void) saveFinished: (NSDocument *)doc didSave:(BOOL)didSave contextInfo:(void *)contextInfo;
{
#ifndef ROOTFILE
    NSString		 *project, *nameString, *projectPath;
#endif
    NSArray		*myList;
    NSString		*theSource, *theKey, *myEngine;
    NSRange		aRange, myRange;
    unsigned int	mystart, myend;
    
    if (whichEngine == LatexEngine)
        withLatex = YES;
    else if (whichEngine == TexEngine)
        withLatex = NO;
    theScript = whichScript;
    
if (! externalEditor) {
    theSource = [[self textView] string];
    if ([self checkMasterFile:theSource forTask:RootForTexing]) return;
#ifdef ROOTFILE
    if ([self checkRootFile_forTask:RootForTexing]) return;
#endif
    rootDocument = nil;
#ifdef NAIRN
    [self checkFileLinks:theSource];
#endif
    myRange.length = 1;
    myRange.location = 0;
    [theSource getLineStart:&mystart end: &myend contentsEnd: nil forRange:myRange];
    if (myend > (mystart + 2)) {
        myRange.location = 0;
        myRange.length = myend - mystart - 1;
        theKey = [theSource substringWithRange:myRange];
        myList = [theKey componentsSeparatedByString:@" "];
        if ((theKey) && ([myList count] > 0)) 
            theKey = [myList objectAtIndex:0];
        }
    else
        theKey = nil;
        
    if ((theKey) && ([theKey isEqualToString:@"%&pdftex"])) {
        withLatex = NO;
        theScript = 100;
        }
    else if ((theKey) && ([theKey isEqualToString:@"%&pdflatex"])) {
        withLatex = YES;
        theScript = 100;
        }
    else if ((theKey) && ([theKey isEqualToString:@"%&tex"])) {
        withLatex = NO;
        theScript = 101;
        }
    else if ((theKey) && ([theKey isEqualToString:@"%&latex"])) {
        withLatex = YES;
        theScript = 101;
        }
    else if ((theKey) && ([theKey isEqualToString:@"%&personaltex"])) {
        withLatex = NO;
        theScript = 102;
        }
    else if ((theKey) && ([theKey isEqualToString:@"%&personallatex"])) {
        withLatex = YES;
        theScript = 102;
        }
    }
    
    if ((! warningGiven) && ((whichEngine == TexEngine) || (whichEngine == LatexEngine)) && (theScript == 100) && ([SUD boolForKey:WarnForShellEscapeKey])) {
        if (withLatex)
            myEngine = [SUD stringForKey:LatexCommandKey];
        else
            myEngine = [SUD stringForKey:TexCommandKey];
             
        // search for --shell-escape
        aRange = [myEngine rangeOfString:@"--shell-escape"];
        if (aRange.location == NSNotFound) 
            warningGiven = YES;
        else {
            NSBeginCriticalAlertSheet(nil, nil, NSLocalizedString(@"Omit Shell Escape", @"Omit Shell Escape"), NSLocalizedString(@"Cancel", @"Cancel"), 
                    textWindow, self, @selector(sheetDidEnd:returnCode:contextInfo:), NULL, nil, 
                    NSLocalizedString(@"Warning: Using Shell Escape", @"Warning: Using Shell Escape"));
            return;
            }
        }
        
    [self completeSaveFinished];
}

- (void) completeSaveFinished
{
    NSString		*myFileName;
    NSMutableArray	*args;
    NSDictionary	*myAttributes;
    NSString		*imagePath;
#ifndef ROOTFILE
    NSString		 *project, *nameString, *projectPath;
#endif
    NSString		*sourcePath;
    NSString		*bibPath;
    NSString		*indexPath;
    NSString		*metaFontPath;
    NSString		*myEngine;
    NSString		*myEngineFirst, *myEngineLast;
    NSString		*enginePath;
    NSString            *mpEngineString;
    NSString            *bibtexEngineString;
    NSString		*tetexBinPath;
    NSRange		aRange;
    unsigned		here;
    

    
    myFileName = [self fileName];
    if ([myFileName length] > 0) {
    
        if (startDate != nil) {
            [startDate release];
            startDate = nil;
            }
            
#ifndef ROOTFILE
            
        projectPath = [[[self fileName] stringByDeletingPathExtension] stringByAppendingPathExtension:@"texshop"];
        if ([[NSFileManager defaultManager] fileExistsAtPath: projectPath]) {
            NSString *projectRoot = [NSString stringWithContentsOfFile: projectPath];
            if ([projectRoot isAbsolutePath]) {
                nameString = [NSString stringWithString:projectRoot];
            }
            else {
                nameString = [[self fileName] stringByDeletingLastPathComponent];
                nameString = [[nameString stringByAppendingString:@"/"] 
                    stringByAppendingString: [NSString stringWithContentsOfFile: projectPath]];
                nameString = [nameString stringByStandardizingPath];
            }
            imagePath = [[nameString stringByDeletingPathExtension] stringByAppendingPathExtension:@"pdf"];
        }
        else
#endif
            imagePath = [[[self fileName] stringByDeletingPathExtension] stringByAppendingPathExtension:@"pdf"];

        if ([[NSFileManager defaultManager] fileExistsAtPath: imagePath]) {
            myAttributes = [[NSFileManager defaultManager] fileAttributesAtPath: imagePath traverseLink:NO];
            startDate = [[myAttributes objectForKey:NSFileModificationDate] retain];
        }
        else
            startDate = nil;
    
#ifndef ROOTFILE
        project = [[[self fileName] stringByDeletingPathExtension] stringByAppendingPathExtension: @"texshop"];
        if ([[NSFileManager defaultManager] fileExistsAtPath: project]) {
            NSString *projectRoot = [NSString stringWithContentsOfFile: project];
            if ([projectRoot isAbsolutePath]) {
                sourcePath = [NSString stringWithString:projectRoot];
            }
            else {
                sourcePath = [[self fileName] stringByDeletingLastPathComponent];
                sourcePath = [[sourcePath stringByAppendingString:@"/"] 
                    stringByAppendingString: projectRoot];
                sourcePath = [sourcePath stringByStandardizingPath];
            }
        }
        else
#endif
            sourcePath = myFileName;
            
            
            
        args = [NSMutableArray array];
        
        outputPipe = [[NSPipe pipe] retain];
        readHandle = [outputPipe fileHandleForReading];
        [readHandle readInBackgroundAndNotify];
        inputPipe = [[NSPipe pipe] retain];
        writeHandle = [inputPipe fileHandleForWriting];

        [outputText setSelectable: YES];
        [outputText selectAll:self];
        [outputText replaceCharactersInRange: [outputText selectedRange] withString:@""];
        [texCommand setStringValue:@""];
        [outputText setSelectable: NO];
        typesetStart = NO; 
       // The following command produces an unwanted tex input event for reasons
       //     I do not understand; the event will be discarded because typesetStart = NO
       //     and it is received before tex output to the console occurs.
       //     RMK; 7/3/2001. 
        [outputWindow makeFirstResponder: texCommand];
        
        
       // [outputWindow setTitle: [[[[self fileName] lastPathComponent] stringByDeletingPathExtension] 
       //         stringByAppendingString:@" console"]];
        [outputWindow setTitle: [[[imagePath lastPathComponent] stringByDeletingPathExtension]
            stringByAppendingString:@" console"]];
        if ([SUD boolForKey:ConsoleBehaviorKey]) {
            if (![outputWindow isVisible])
                [outputWindow orderBack: self];
            [outputWindow makeKeyWindow];
            }
        else
            [outputWindow makeKeyAndOrderFront: self];


 
     //   if (whichEngine < 5)
        if ((whichEngine == TexEngine) || (whichEngine == LatexEngine) || (whichEngine == MetapostEngine) || (whichEngine == ContextEngine))
        {
            if ((theScript == 101) && ([SUD boolForKey:SavePSEnabledKey]) 
        //        && (whichEngine != 2)   && (whichEngine != 4))
                && (whichEngine != MetapostEngine) && (whichEngine != ContextEngine))
            	[args addObject: [NSString stringWithString:@"--keep-psfile"]];
                
            if (texTask != nil) {
                [texTask terminate];
                [texTask release];
                texTask = nil;
                }
            texTask = [[NSTask alloc] init];
            [texTask setCurrentDirectoryPath: [sourcePath stringByDeletingLastPathComponent]];
            [texTask setEnvironment: TSEnvironment];
            
            if (whichEngine ==ContextEngine) {
                if (theScript == 100) {
                    enginePath = [[NSBundle mainBundle] pathForResource:@"contextwrap" ofType:nil];
                    [args addObject: [[SUD stringForKey:TetexBinPathKey] stringByAppendingString:@"/"]];
                    }
                else {
                    enginePath = [[NSBundle mainBundle] pathForResource:@"contextdviwrap" ofType:nil];
                    [args addObject: [[SUD stringForKey:TetexBinPathKey] stringByAppendingString:@"/"]];
                     if ((theScript == 101) && ([SUD boolForKey:SavePSEnabledKey])) 
                        [args addObject: @"yes"];
                     else
                        [args addObject: @"no"];
                   // if ([SUD boolForKey:SavePSEnabledKey]) 
                   //     [args addObject: [NSString stringWithString:@"--keep-psfile"]];
                    }
                 }
           
        
        //    else if (whichEngine == 3)
        //        myEngine = @"omega"; // currently this should never occur
        
                
            else if (whichEngine == MetapostEngine)
                {
                switch ([SUD integerForKey:MetaPostCommandKey]) {
                    case 0: mpEngineString = @"mptopdfwrap"; break;
                    case 1: mpEngineString = @"metapostwrap"; break;
                    default: mpEngineString = @"mptopdfwrap"; break;
                    }
                enginePath = [[NSBundle mainBundle] pathForResource:mpEngineString ofType:nil];
                [args addObject: [[SUD stringForKey:TetexBinPathKey] stringByAppendingString:@"/"]];
                 }
                
            else switch (theScript) {
            
                case 100: 
                
                    if (withLatex)
                        myEngine = [SUD stringForKey:LatexCommandKey];
                    else
                        myEngine = [SUD stringForKey:TexCommandKey];
                        
                    if (omitShellEscape) {
                        aRange = [myEngine rangeOfString:@"--shell-escape"];
                        if (aRange.location == NSNotFound) 
                            warningGiven = YES;
                        else {
                            myEngineFirst = [myEngine substringToIndex: aRange.location];
                            here = aRange.location + aRange.length;
                            myEngineLast = [myEngine substringFromIndex: here];
                            myEngine = [myEngineFirst stringByAppendingString: myEngineLast];
                            }
                        }
                    break;
                
                case 101:
                
                    if (withLatex)
                        myEngine = [SUD stringForKey:LatexGSCommandKey];
                    else
                        myEngine = [SUD stringForKey:TexGSCommandKey];
                    break;
                
                case 102:
                
                    if (withLatex)
                        myEngine = [SUD stringForKey:LatexScriptCommandKey];
                    else
                        myEngine = [SUD stringForKey:TexScriptCommandKey];
                        
                    if ([myEngine length] == 0) {
                        if (withLatex)
                            myEngine = [SUD stringForKey:LatexCommandKey];
                        else
                            myEngine = [SUD stringForKey:TexCommandKey];
                        }
                        
                    break;
                
                }
                
                       
          //  if ((whichEngine != 2) && (whichEngine != 3) && (whichEngine != 4)) {
            if ((whichEngine != MetapostEngine) && (whichEngine != ContextEngine)) {
                
            myEngine = [self separate:myEngine into:args];
                
              enginePath = nil;
              
              if ((myEngine != nil) && ([myEngine length] > 0)) {       
                if ([myEngine characterAtIndex:0] != '/') {
                    tetexBinPath = [[SUD stringForKey:TetexBinPathKey] stringByAppendingString:@"/"];
                    enginePath = [tetexBinPath stringByAppendingString:myEngine];
                     }
                else
                    enginePath = myEngine;
                }
                
            }
            
            // Koch: Feb 20; this allows spaces everywhere in path except
            // file name itself 
            [args addObject: [sourcePath lastPathComponent]];
        
            if ((enginePath != nil) && ([[NSFileManager defaultManager] fileExistsAtPath: enginePath])) {
                [texTask setLaunchPath:enginePath];
                [texTask setArguments:args];
                [texTask setStandardOutput: outputPipe];
                [texTask setStandardError: outputPipe];
                [texTask setStandardInput: inputPipe];
                [texTask launch];
            }
            else {
                [inputPipe release];
                [outputPipe release];
                [texTask release];
                texTask = nil;
            }
        }
        else if (whichEngine == BibtexEngine) {
            bibPath = [sourcePath stringByDeletingPathExtension];
            // Koch: ditto; allow spaces in path 
            [args addObject: [bibPath lastPathComponent]];
        
            if (bibTask != nil) {
                [bibTask terminate];
                [bibTask release];
                bibTask = nil;
            }
            bibTask = [[NSTask alloc] init];
            [bibTask setCurrentDirectoryPath: [sourcePath  stringByDeletingLastPathComponent]];
            [bibTask setEnvironment: TSEnvironment];
            tetexBinPath = [[SUD stringForKey:TetexBinPathKey] stringByAppendingString:@"/"];
            
             switch ([SUD integerForKey:BibtexCommandKey]) {
                    case 0: bibtexEngineString = @"bibtex"; break;
                    case 1: bibtexEngineString = @"jbibtex"; break;
                    default: bibtexEngineString = @"bibtex"; break;
                    }
            enginePath = [tetexBinPath stringByAppendingString:bibtexEngineString];
            [bibTask setLaunchPath: enginePath];
            [bibTask setArguments:args];
            [bibTask setStandardOutput: outputPipe];
            [bibTask setStandardError: outputPipe];
            [bibTask setStandardInput: inputPipe];
            [bibTask launch];
        }
        else if (whichEngine == IndexEngine) {
            indexPath = [sourcePath stringByDeletingPathExtension];
            // Koch: ditto, spaces in path 
            [args addObject: [indexPath lastPathComponent]];
        
            if (indexTask != nil) {
                [indexTask terminate];
                [indexTask release];
                indexTask = nil;
            }
            indexTask = [[NSTask alloc] init];
            [indexTask setCurrentDirectoryPath: [sourcePath  stringByDeletingLastPathComponent]];
            [indexTask setEnvironment: TSEnvironment];
            tetexBinPath = [[SUD stringForKey:TetexBinPathKey] stringByAppendingString:@"/"];
            enginePath = [tetexBinPath stringByAppendingString:@"makeindex"];
            [indexTask setLaunchPath: enginePath];
            [indexTask setArguments:args];
            [indexTask setStandardOutput: outputPipe];
            [indexTask setStandardError: outputPipe];
            [indexTask setStandardInput: inputPipe];
            [indexTask launch];
        }
        else if (whichEngine == MetafontEngine) {
            metaFontPath = [sourcePath stringByDeletingPathExtension];
            // Koch: ditto, spaces in path 
            [args addObject: [metaFontPath lastPathComponent]];
        
            if (metaFontTask != nil) {
                [metaFontTask terminate];
                [metaFontTask release];
                metaFontTask = nil;
            }
            metaFontTask = [[NSTask alloc] init];
            [metaFontTask setCurrentDirectoryPath: [sourcePath  stringByDeletingLastPathComponent]];
            [metaFontTask setEnvironment: TSEnvironment];
            tetexBinPath = [[SUD stringForKey:TetexBinPathKey] stringByAppendingString:@"/"];
            enginePath = [tetexBinPath stringByAppendingString:@"mf"];
            [metaFontTask setLaunchPath: enginePath];
            [metaFontTask setArguments:args];
            [metaFontTask setStandardOutput: outputPipe];
            [metaFontTask setStandardError: outputPipe];
            [metaFontTask setStandardInput: inputPipe];
            [metaFontTask launch];
        }
    }
}


-(void)sheetDidEnd:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo
{
   switch(returnCode) {
   
    case NSAlertDefaultReturn:
        warningGiven = YES;
        [self completeSaveFinished];
        break;
        
    case NSAlertAlternateReturn: // this says omit --shell-escape
        warningGiven = YES;
        omitShellEscape = YES;
        [self completeSaveFinished];
        break;
        
    case NSAlertOtherReturn:
        break;
    }
}

- (void) doTex: sender 
{
// added by mitsu --(J++) Program popup button indicating Program name
	[programButton selectItemWithTitle: @"Plain TeX"]; 
	[programButtonEE selectItemWithTitle: @"Plain TeX"];
// end addition

    [self doJob:TexEngine withError:YES];
}

- (void) doLatex: sender;
{
// added by mitsu --(J++) Program popup button indicating Program name
	[programButton selectItemWithTitle: @"LaTeX"]; 
	[programButtonEE selectItemWithTitle: @"LaTeX"];
// end addition

    [self doJob:LatexEngine withError:YES];
}

- (void) doContext: sender;
{
// added by mitsu --(J++) Program popup button indicating Program name
	[programButton selectItemWithTitle: @"ConTeXt"]; 
	[programButtonEE selectItemWithTitle: @"ConTeXt"];
// end addition

    [self doJob:ContextEngine withError:YES];
}

- (void) doMetapost: sender;
{
// added by mitsu --(J++) Program popup button indicating Program name
	[programButton selectItemWithTitle: @"MetaPost"]; 
	[programButtonEE selectItemWithTitle: @"MetaPost"];
// end addition

    [self doJob:MetapostEngine withError:YES];
}

- (void) doBibtex: sender;
{
// added by mitsu --(J++) Program popup button indicating Program name
	[programButton selectItemWithTitle: @"BibTeX"]; 
	[programButtonEE selectItemWithTitle: @"BibTeX"];
// end addition

    [self doJob:BibtexEngine withError:NO];
}

- (void) doIndex: sender;
{
// added by mitsu --(J++) Program popup button indicating Program name
	[programButton selectItemWithTitle: @"MakeIndex"]; 
	[programButtonEE selectItemWithTitle: @"MakeIndex"];
// end addition

    [self doJob:IndexEngine withError:NO];
}

- (void) doMetaFont: sender;
{
// added by mitsu --(J++) Program popup button indicating Program name
	[programButton selectItemWithTitle: @"MetaFont"]; 
	[programButtonEE selectItemWithTitle: @"MetaFont"];
// end addition

    [self doJob:MetafontEngine withError:NO];
}

- (void) doTypesetEE: sender;
{
    [self doTypeset: sender];
}

- (void) doTypeset: sender;
{
//    NSString	*titleString;
    BOOL	useError;
   
   useError = NO;
   if ((whichEngine == TexEngine) || (whichEngine == LatexEngine) || (whichEngine == MetapostEngine) || (whichEngine == ContextEngine))
    useError = YES;
// changed by mitsu --(J) Typeset commmand
	[self doJob: whichEngine withError:useError];
// end change

/* 
    titleString = [sender title];
    if ([titleString isEqualToString: @"TeX"]) 
        [self doTex:self];
    else if ([titleString isEqualToString: @"LaTeX"])
        [self doLatex: self];
    else if ([titleString isEqualToString: @"MetaPost"])
        [self doMetapost: self];
    else if ([titleString isEqualToString: @"ConTeXt"])
        [self doContext: self];
    else if ([titleString isEqualToString: @"BibTeX"])
        [self doBibtex: self];
    else if ([titleString isEqualToString: @"Index"])
        [self doIndex: self];
    else if ([titleString isEqualToString: @"MetaFont"])
        [self doMetaFont: self];
*/
}

- (void) doTexCommand: sender;
{
    NSData *myData;
    NSString *command;
    
    if ((typesetStart) && (inputPipe)) {
        command = [[texCommand stringValue] stringByAppendingString:@"\n"];
// added by mitsu --(F) TeXInput in Console Window with yen character
			if (shouldFilter == filterMacJ) {
				command = filterYenToBackslash(command);
			}
// end addition

        myData = [command dataUsingEncoding: NSMacOSRomanStringEncoding allowLossyConversion:YES];
            [writeHandle writeData: myData];
            // added by mitsu --(L) reflect tex input and clear tex input field in console window
            NSRange selectedRange = [outputText selectedRange];
            selectedRange.location += selectedRange.length;
            selectedRange.length = 0;
            // in the next two lines, replace "command" by "old command" after Japanese modification made -- koch
            [outputText replaceCharactersInRange: selectedRange withString: command];
            selectedRange.length = [command length];
            [outputText setTextColor: [NSColor redColor] range: selectedRange];
            [outputText scrollRangeToVisible: selectedRange];
            [texCommand setStringValue: @""];
            // end addition

        }
        

}

- (void) printSource: sender;
{
   
    NSPrintOperation	*printOperation;
    NSPrintInfo		*myPrintInfo;
    
    myPrintInfo = [self printInfo];
    [myPrintInfo setHorizontalPagination: NSFitPagination];
    [myPrintInfo setVerticallyCentered:NO];

    printOperation = [NSPrintOperation printOperationWithView:textView printInfo: myPrintInfo];
    [printOperation setShowPanels:YES];
    [printOperation runOperation];

}

- (void) chooseProgramEE: sender;
{
    [self chooseProgram: sender];
}


- (void) chooseProgram: sender;
{
    id		theItem;
    int		which;
 
    
    theItem = [sender selectedItem];
    which = [theItem tag];
    [programButton selectItemAtIndex: (which - 1)];
    [programButtonEE selectItemAtIndex: (which - 1)];
 
 // added by mitsu --(J) Typeset command
	[[TSWindowManager sharedInstance] checkProgramMenuItem: whichEngine checked: NO];
	whichEngine = which;  // remember it
	[[TSWindowManager sharedInstance] checkProgramMenuItem: whichEngine checked: YES];
        [self fixMacroMenu];
// end addition

    /*   
    switch (which) {
    
        case 0:
            [typesetButton setTitle: @"TeX"];
            [typesetButtonEE setTitle: @"TeX"];
            break;
        
        case 1:
            [typesetButton setTitle: @"LaTeX"];
            [typesetButtonEE setTitle: @"LaTeX"];
            break;

        case 2:
            [typesetButton setTitle: @"BibTeX"];
            [typesetButtonEE setTitle: @"BibTeX"];
            break;
            
        case 3:
            [typesetButton setTitle: @"Index"];
            [typesetButtonEE setTitle: @"Index"];
            break;
            
        case 4:
            [typesetButton setTitle: @"MetaPost"];
            [typesetButtonEE setTitle: @"MetaPost"];
            break;
            
        case 5:
            [typesetButton setTitle: @"ConTeXt"];
            [typesetButtonEE setTitle: @"ConTeXt"];
            break;
            
        case 6:
            [typesetButton setTitle: @"MetaFont"];
            [typesetButtonEE setTitle: @"MetaFont"];
            break;
        }
    */
}

- (void) okProject: sender;
{
    myPrefResult = 0;
    [projectPanel close];
}

- (void) quitProject: sender;
{
    myPrefResult = 1;
    [projectPanel close];
}


- (void) okForRequest: sender;
{
    myPrefResult = 0;
    [requestWindow close];
}

- (void) okForPrintRequest: sender;
{
    myPrefResult = 0;
    [printRequestPanel close];
}


- (void) okLine: sender;
{
    myPrefResult = 0;
    [linePanel close];
}

- (void) quitLine: sender;
{
    myPrefResult = 1;
    [linePanel close];
}

- (void) setProjectFile: sender;
{
     int		result;
     NSString		*project, *nameString; //, *anotherString;
     
     if (! [self fileName]) {
        result = [NSApp runModalForWindow: requestWindow];
        }
     else {
     
        myPrefResult = 2;
        project = [[[self fileName] stringByDeletingPathExtension]
            stringByAppendingString: @".texshop"];
        if ([[NSFileManager defaultManager] fileExistsAtPath: project]) {
            nameString = [NSString stringWithContentsOfFile: project];
            [projectName setStringValue: nameString];
            }
        else
            [projectName setStringValue: [[self fileName] lastPathComponent]];
        [projectName selectText: self];
        result = [NSApp runModalForWindow: projectPanel];
        if (result == 0) {
            nameString = [projectName stringValue];
//            if ([nameString isAbsolutePath])
                [nameString writeToFile: project atomically: YES];
//           else {
//                anotherString = [[self fileName] stringByDeletingLastPathComponent];
//                anotherString = [[anotherString stringByAppendingString:@"/"] 
//                        stringByAppendingString: nameString];
//                nameString = [anotherString stringByStandardizingPath];
//                [nameString writeToFile: project atomically: YES];
//                } 
            }
    }
}

- (void) doLine: sender;
{
    int		result, line;

    myPrefResult = 2;
    result = [NSApp runModalForWindow: linePanel];
    if (result == 0) {
        line = [lineBox intValue];
        [self toLine: line];
        }
}


- (void) doTag: sender;
{
    NSString	*text, *tagString, *title, *mainTitle;
    unsigned	start, end, irrelevant;
    NSRange	myRange, nameRange, gotoRange;
    unsigned	length;
    int		theChar;
    int		sectionIndex = -1;
    unsigned	lineNumber = 0;
    unsigned	lineNumber2;
    BOOL	done;

// Minor Zenitani fix
//  title = [tags titleOfSelectedItem];
//  lineNumber2 = [[tags selectedItem] tag];

    title = [sender title];
    lineNumber2 = [sender tag];
    
    /* code by Anton Leuski */
    if ([SUD boolForKey: TagSectionsKey]) { 
		unsigned  i;
		for(i = 0; i < [kTaggedTeXSections count]; ++i) {
			NSString*  tag = [kTaggedTagSections objectAtIndex:i];
			if ([title hasPrefix:tag]) {
				sectionIndex = i;
                                myRange.location = [tag length];
                                myRange.length = [title length] - myRange.location;
                                mainTitle = [title substringWithRange: myRange];
				break;
			}
		}
	}
    
        
    text = [textView string];
    length = [text length];
    myRange.location = 0;
    myRange.length = 1;
    done = NO;

    while ((myRange.location < length) && (!done)) {
        [text getLineStart: &start end: &end contentsEnd: &irrelevant forRange: myRange];
        myRange.location = end;
        lineNumber++;
        
        if ( lineNumber == lineNumber2 ){

            if (start < length - 3) {
                theChar = [text characterAtIndex: start];
                if (theChar == 0x0025) {
                    theChar = [text characterAtIndex: (start + 1)];
                    if (theChar == 0x003a) {
                        nameRange.location = start + 2;
                        nameRange.length = (end - start - 2);
                        tagString = [text substringWithRange: nameRange];
                        if ([title isEqualToString:tagString]) {
                            done = YES;
                            gotoRange.location = start;
                            gotoRange.length = (end - start);
                            [textView setSelectedRange: gotoRange];
                            [textView scrollRangeToVisible: gotoRange];
                            }
                        }
                    }
    
                /* code by Anton Leuski */
                else if ((theChar == texChar) && (start < length - 8) && (sectionIndex >= 0)) {
                            
                    NSString*  tag	= [kTaggedTeXSections objectAtIndex:sectionIndex];
                    nameRange.location	= start;
                    nameRange.length	= [tag length];
                    tagString 		= [text substringWithRange: nameRange];
    
                    if ([tagString isEqualToString:tag]) {
                                    
                        nameRange.location = start + nameRange.length;
                        nameRange.length = (end - start - nameRange.length);
                        tagString = [text substringWithRange: nameRange];
                                            
                        if ([mainTitle isEqualToString:tagString]) {
                            done = YES;
                            gotoRange.location = start;
                            gotoRange.length = (end - start);
                            [textView setSelectedRange: gotoRange];
                            [textView scrollRangeToVisible: gotoRange];
                            }
                        }
                    
                    }
                }
            }
	}
}


- (void) setupTags;
{
    if ([SUD boolForKey: TagSectionsKey]) {
        if (tagTimer != nil) 
            {
            [tagTimer invalidate];
            [tagTimer release];
            tagTimer = nil;
            }
        tagLocation = 0;
        tagLocationLine = 0;
        [tags removeAllItems];
        [tags addItemWithTitle:NSLocalizedString(@"Tags", @"Tags")];
        tagTimer = [[NSTimer scheduledTimerWithTimeInterval: .02 target:self selector:@selector(fixTags:) userInfo:nil repeats:YES] retain];
        }
}

- (void) doChooseMethod: sender;
{
    [[[[[NSApp mainMenu] itemWithTitle:NSLocalizedString(@"Typeset", @"Typeset")] submenu] 
        itemWithTag:100] setState:NSOffState];
    [[[[[NSApp mainMenu] itemWithTitle:NSLocalizedString(@"Typeset", @"Typeset")] submenu] 
        itemWithTag:101] setState:NSOffState];
    [[[[[NSApp mainMenu] itemWithTitle:NSLocalizedString(@"Typeset", @"Typeset")] submenu] 
        itemWithTag:102] setState:NSOffState];
    [sender setState:NSOnState];
    whichScript = [sender tag]; 
}

- (void) fixTypesetMenu;
{
    NSMenuItem 	*aMenu;
    int		i;
    
    for (i = 100; i <= 102; i++) {
        aMenu = [[[[NSApp mainMenu] itemWithTitle:NSLocalizedString(@"Typeset", @"Typeset")] 
            submenu] itemWithTag:i]; 
        if (whichScript == i)
            [aMenu setState:NSOnState];
        else
            [aMenu setState:NSOffState];
        }
}

- (void)newMainWindow:(NSNotification *)notification
{
	id object = [notification object];
        if ((object == pdfWindow) || (object == textWindow) || (object == outputWindow))
            [self fixTypesetMenu];
}

- (int) errorLineFor: (int)theError{
    if (theError < errorNumber)
        return errorLine[theError];
    else
        return -1;
}

- (int) totalErrors{
    return errorNumber;
}


- (void) doError: sender;
{
    NSDocument		*myRoot;
    NSArray 		*wlist;
    NSEnumerator	*en;
    id			obj;
    BOOL		doError;
    int			myErrorNumber;
    int			myErrorLine;
    
    myRoot = nil;
    doError = NO;
    
    if (rootDocument != nil) {
        wlist=[NSApp orderedDocuments];
        en=[wlist objectEnumerator];
        while(obj=[en nextObject]) {
            if (obj == rootDocument)
                myRoot = rootDocument;
            }
        }
        
    if (rootDocument == nil) {
        if (errorNumber > 0) {
            doError = YES;
            if (whichError >= errorNumber)
                whichError = 0;			// warning; main.tex could be closed in the middle of error processing
            myErrorLine = errorLine[whichError];
            whichError++;
            if (whichError >= errorNumber)
                whichError = 0;
            }
        }
    else {
        myErrorNumber = [rootDocument totalErrors];
        if (myErrorNumber > 0) {
            doError = YES;
            if (whichError >= myErrorNumber)
                whichError = 0;
            myErrorLine = [rootDocument errorLineFor: whichError];
            whichError++;
            if (whichError >= myErrorNumber)
                whichError = 0;
            }
        }
    
    
    if ((!externalEditor) && (fileIsTex) && (doError)) {
            [textWindow makeKeyAndOrderFront: self];
            [self toLine: myErrorLine];
            }
}

- (void) toLine: (int) line;
{
    int		i;
    NSString	*text;
    unsigned	start, end, irrelevant, stringlength;
    NSRange	myRange;

    if (line < 1) return;
    text = [textView string];
    stringlength = [text length];
    myRange.location = 0;
    myRange.length = 1;
    i = 1;
    while ((i <= line) && (myRange.location < stringlength)) {
        [text getLineStart: &start end: &end contentsEnd: &irrelevant forRange: myRange];
        myRange.location = end;
        i++;
        }
    if (i == (line + 1)) {
        myRange.location = start;
        myRange.length = (end - start);
        [textView setSelectedRange: myRange];
        [textView scrollRangeToVisible: myRange];
        }
    
}

- (id) pdfWindow;
{
    return pdfWindow;
}

- (id) textWindow;
{
    return textWindow;
}

- (id) textView;
{
    return textView;
}


- (int) imageType;
{
    return myImageType;
}

- (NSPDFImageRep *) myTeXRep;
{
    return texRep;
}

- (BOOL)fileIsTex
{
    return fileIsTex;
}


/*
- (BOOL)validateMenuItem:(NSMenuItem *)anItem {
    BOOL  result;
    
    result = [super validateMenuItem: anItem];
    if (fileIsTex)
        return result;
    else if ([[anItem title] isEqualToString:NSLocalizedString(@"Save", @"Save")]) {
        if (myImageType == isOther)
            return YES;
        else
            return NO;
        }
    else if([[anItem title] isEqualToString:NSLocalizedString(@"Print Source...", @"Print Source...")]) {
        if (myImageType == isOther)
            return YES;
        else
            return NO;
        }
    else if ([[anItem title] isEqualToString:@"Plain TeX"]) {
        return NO;
        }
    else if ([[anItem title] isEqualToString:@"LaTeX"]) {
        return NO;
        }
    else if ([[anItem title] isEqualToString:@"BibTeX"]) {
        return NO;
        }
    else if ([[anItem title] isEqualToString:@"MakeIndex"]) {
        return NO;
        }
    else if ([[anItem title] isEqualToString:@"MetaPost"]) {
        return NO;
        }
    else if ([[anItem title] isEqualToString:@"ConTeXt"]) {
        return NO;
        }
    else if ([[anItem title] isEqualToString: NSLocalizedString(@"Print...", @"Print...")]) {
        if ((myImageType == isPDF) || (myImageType == isJPG) || (myImageType == isTIFF))
            return YES;
        else
            return NO;
        }
    else if ([[anItem title] 
            isEqualToString: NSLocalizedString(@"Set Project Root...", @"Set Project Root...")]) {
        return NO;
        }
    else return result;
}
*/

// Revised code by Max Horn

- (BOOL)validateMenuItem:(NSMenuItem *)anItem {

    if (!fileIsTex) {
		if ([anItem action] == @selector(saveDocument:) || 
			[anItem action] == @selector(printSource:))
			return (myImageType == isOther);
		if ([anItem action] == @selector(doTex:) ||
			[anItem action] == @selector(doLatex:) ||
			[anItem action] == @selector(doBibtex:) ||
			[anItem action] == @selector(doIndex:) ||
			[anItem action] == @selector(doMetapost:) ||
			[anItem action] == @selector(doContext:))
			return NO;
		if ([anItem action] == @selector(printDocument:))
			return ((myImageType == isPDF) ||
					(myImageType == isJPG) ||
					(myImageType == isTIFF));
		if ([anItem action] == @selector(setProjectFile:))
			return NO;
                        
	}
        
        // forsplit        
        if ([anItem action] == @selector(splitWindow:)) {
            if (windowIsSplit)
                [anItem setState:NSOnState];
            else
                [anItem setState:NSOffState];
            return YES;
            }
        // end forsplit

	
	return [super validateMenuItem: anItem];
}



- (void)textDidChange:(NSNotification *)aNotification;
{
  [self fixColor :colorStart :colorEnd];
    if (tagLine) 
        [self setupTags];
    colorStart = 0;
    colorEnd = 0;
    returnline = NO;
    tagLine = NO;
   // [self updateChangeCount: NSChangeDone];
}

BOOL isText1(int c) {
    if ((c >= 0x0041) && (c <= 0x005a))
        return YES;
    else if ((c >= 0x0061) && (c <= 0x007a))
        return YES;
    else
        return NO;
    }

// fixColor2 is the old fixcolor, now only used when opening documents
- (void)fixColor2: (unsigned)from : (unsigned)to
{
    NSRange	colorRange;
    NSString	*textString;
    NSColor	*regularColor;
    long	length, location, final;
    unsigned	start1, end1;
    int		theChar;
    unsigned	end;
    
    if ((! [SUD boolForKey:SyntaxColoringEnabledKey]) || (! fileIsTex)) return;
    
    regularColor = [NSColor blackColor];
 
    textString = [textView string];
    if (textString == nil) return;
    length = [textString length];
    // [[textView textStorage] beginEditing];
    [textStorage beginEditing];

    
    colorRange.location = 0;
    colorRange.length = length;
    [textString getLineStart:&start1 end:&end1 contentsEnd:&end forRange:colorRange];
    location = start1;
    final = end1;
    colorRange.location = start1;
    colorRange.length = end1 - start1;
    
    [textView setTextColor: regularColor range: colorRange];
        
    // NSLog(@"begin");
    while (location < final) {
            theChar = [textString characterAtIndex: location];
            
             if ((theChar == 0x007b) || (theChar == 0x007d) || (theChar == 0x0024)) {
                colorRange.location = location;
                colorRange.length = 1;
                [textView setTextColor: markerColor range: colorRange];
                colorRange.location = colorRange.location + colorRange.length - 1;
                colorRange.length = 0;
                [textView setTextColor: regularColor range: colorRange];
                location++;
                }
                
             else if (theChar == 0x0025) {
                colorRange.location = location;
                colorRange.length = 0;
                [textString getLineStart:NULL end:NULL contentsEnd:&end forRange:colorRange];
                colorRange.length = (end - location);
                [textView setTextColor: commentColor range: colorRange];
                colorRange.location = colorRange.location + colorRange.length - 1;
                colorRange.length = 0;
                [textView setTextColor: regularColor range: colorRange];
                location = end;
                }
                
             else if (theChar == texChar) {
                colorRange.location = location;
                colorRange.length = 1;
                location++;
                if ((location < final) && ([textString characterAtIndex: location] == 0x0025)) {
                    colorRange.length = location - colorRange.location;
                    location++;
                    }
                else while ((location < final) && (isText1([textString characterAtIndex: location]))) {
                    location++;
                    colorRange.length = location - colorRange.location;
                    }
                [textView setTextColor: commandColor range: colorRange];
                colorRange.location = location;
                colorRange.length = 0;
                [textView setTextColor: regularColor range: colorRange];
                }

            else
                location++;
            }
            
        // [[textView textStorage] endEditing];
        [textStorage endEditing];

        
}



- (BOOL)textView:(NSTextView *)aTextView shouldChangeTextInRange:(NSRange)affectedCharRange replacementString:(NSString *)replacementString
{
    NSRange			matchRange, tagRange;
    NSString			*textString;
    int				i, j, count, uchar, leftpar, rightpar, aChar;
    BOOL			done;
    NSDate			*myDate;
    unsigned 			start, end, end1;
    NSMutableAttributedString 	*myAttribString;
    NSDictionary		*myAttributes;
    NSColor			*previousColor;
   
    fastColor = NO;
    if (affectedCharRange.length == 0)
        fastColor = YES;
    else if (affectedCharRange.length == 1) {
        aChar = [[textView string] characterAtIndex: affectedCharRange.location];
        if (/* (aChar >= 0x0020) && */ (aChar != 165) && (aChar != 0x005c) && (aChar != 0x0025))
            fastColor = YES;
        if (aChar == 0x005c) {
            fastColor = YES;
            myAttribString = [[[NSMutableAttributedString alloc] initWithAttributedString:[textView 					attributedSubstringFromRange: affectedCharRange]] autorelease];
            myAttributes = [myAttribString attributesAtIndex: 0 effectiveRange: NULL];
            // mitsu 1.29 parhaps this (and several others below) can be replaced by
            // myAttributes = [[textView textStorage] attributesAtIndex: 
            // 					affectedCharRange.location effectiveRange: NULL];
            // end mitsu 1.29 and myAttribString is not necessary
            previousColor = [myAttributes objectForKey:NSForegroundColorAttributeName];
            if (previousColor != commentColor) 
                fastColorBackTeX = YES;
            }
        }
    
    colorStart = affectedCharRange.location;
    colorEnd = colorStart;
    
    
    tagRange = [replacementString rangeOfString:@"%:"];
    if (tagRange.length != 0)
        tagLine = YES;
        
    // added by S. Zenitani -- "\n" increments tagLocationLine
    tagRange = [replacementString rangeOfString:@"\n"];
    if (tagRange.length != 0)
        tagLine = YES;
    // end

        
    textString = [textView string];
    [textString getLineStart:&start end:&end contentsEnd:&end1 forRange:affectedCharRange];
    tagRange.location = start;
    tagRange.length = end - start;
    matchRange = [textString rangeOfString:@"%:" options:0 range:tagRange];
    if (matchRange.length != 0)
        tagLine = YES;

    // for tagLocationLine (2) Zenitani
    matchRange = [textString rangeOfString:@"\n" options:0 range:tagRange];
    if (matchRange.length != 0)
        tagLine = YES;

/* code by Anton Leuski */
 if ([SUD boolForKey: TagSectionsKey]) {
	
    unsigned	i;
    for(i = 0; i < [kTaggedTeXSections count]; ++i) {
        tagRange = [replacementString rangeOfString:[kTaggedTeXSections objectAtIndex:i]];
        if (tagRange.length != 0) {
            tagLine = YES;
            break;
            }
        }
            
    if (!tagLine) {

        textString = [textView string];
        [textString getLineStart:&start end:&end 
            contentsEnd:&end1 forRange:affectedCharRange];
        tagRange.location	= start;
        tagRange.length		= end - start;

        for(i = 0; i < [kTaggedTeXSections count]; ++i) {
            matchRange = [textString rangeOfString:
                [kTaggedTeXSections objectAtIndex:i] options:0 range:tagRange];
            if (matchRange.length != 0) {
                tagLine = YES;
                break;
                }
            }

        }
    }
    
   if (replacementString == nil) 
        return YES;
    else
        colorEnd = colorStart + [replacementString length];
    
    if ([replacementString length] != 1) return YES;
    rightpar = [replacementString characterAtIndex:0];
    
// mitsu 1.29 (T4) compare with "inserText:" in MyTextView.m
#define AUTOCOMPLETE_IN_INSERTTEXT
#ifndef AUTOCOMPLETE_IN_INSERTTEXT
// end mitsu 1.29

    
    // Code added by Greg Landweber for auto-completions of '^', '_', etc.
    // Should provide a preference setting for users to turn it off!
    // First, avoid completing \^, \_, \"
   //  if ([SUD boolForKey:AutoCompleteEnabledKey]) {
        if (doAutoComplete) {
        if ( rightpar >= 128 ||
            [textView selectedRange].location == 0 ||
            [textString characterAtIndex:[textView selectedRange].location - 1 ] != texChar ) {
        
                NSString *completionString = [autocompletionDictionary objectForKey:replacementString];
                if ( completionString && (shouldFilter != filterMacJ || [replacementString
                    characterAtIndex:0]!=texChar)) {
                    // should really send this as a notification, instead of calling it directly,
                    // or should separate out the code that actually performs the completion
                    // from the code that responds to the notification sent by the LaTeX panel.
                    // mitsu 1.29 (T4)
                    [self insertSpecialNonStandard:completionString 
                                undoKey: NSLocalizedString(@"Autocompletion", @"Autocompletion")];
                    //[textView insertSpecialNonStandard:completionString 
                    //			undoKey: NSLocalizedString(@"Autocompletion", @"Autocompletion")];
                    // original was
                    //    [self doCompletion:[NSNotification notificationWithName:@"" object:completionString]];
                    // end mitsu 1.29
                    return NO;
                }
            }
        }
   
    // End of code added by Greg Landweber
// mitsu 1.29 (T4)
#endif
// end mitsu 1.29


    if (rightpar == 0x000a)
        returnline = YES;
        
    if (! [SUD boolForKey:ParensMatchingEnabledKey]) return YES;
    if ((rightpar != 0x007D) &&  (rightpar != 0x0029) &&  (rightpar != 0x005D)) return YES;

    if (rightpar == 0x007D) 
        leftpar = 0x007B;
    else if (rightpar == 0x0029) 
        leftpar = 0x0028;
    else 
        leftpar = 0x005B;
    
    textString = [textView string];    
    i = affectedCharRange.location;
    j = 1;
    count = 1;
    done = NO;
    /* modified Jan 26, 2001, so we don't search entire text */
    while ((i > 0) && (j < 5000) && (! done)) {
        i--; j++;
        uchar = [textString characterAtIndex:i];
        if (uchar == rightpar)
            count++;
        else if (uchar == leftpar)
            count--;
        if (count == 0) {
            done = YES;
            matchRange.location = i;
            matchRange.length = 1;
            /* koch: here 'affinity' and 'stillSelecting' are necessary,
            else the wrong range is selected. */
            [textView setSelectedRange: matchRange 
                affinity: NSSelectByCharacter stillSelecting: YES];
            [textView display];
            myDate = [NSDate date];
            /* Koch: Jan 26, 2001: changed -0.15 to -0.075 to speed things up */
            while ([myDate timeIntervalSinceNow] > - 0.075);
            [textView setSelectedRange: affectedCharRange];
            }
        }
    return YES;
}


- (NSRange)textView:(NSTextView *)aTextView willChangeSelectionFromCharacterRange:(NSRange)oldSelectedCharRange toCharacterRange:(NSRange)newSelectedCharRange
{
    return newSelectedCharRange;
/*
    NSRange	replacementRange;
    NSString	*textString;
    int		length, i, j;
    BOOL	done;
    int		leftpar, rightpar, count, uchar;
    
    if (newSelectedCharRange.length != 1) return newSelectedCharRange;
    textString = [textView string];
    if (textString == nil) return newSelectedCharRange;
    length = [textString length];
    i = newSelectedCharRange.location;
    if (i >= length) return newSelectedCharRange;
    rightpar = [textString characterAtIndex: i];
    
    if ((rightpar == 0x007D) || (rightpar == 0x0029) || (rightpar == 0x005D)) {
           j = i;
            if (rightpar == 0x007D) 
                leftpar = 0x007B;
            else if (rightpar == 0x0029) 
                leftpar = 0x0028;
            else 
                leftpar = 0x005B;
            count = 1;
            done = NO;
            while ((i > 0) && (! done)) {
                i--;
                uchar = [textString characterAtIndex:i];
                if (uchar == rightpar)
                    count++;
                else if (uchar == leftpar)
                    count--;
                if (count == 0) {
                    done = YES;
                    replacementRange.location = i;
                    replacementRange.length = j - i + 1;
                    return replacementRange;
                    }
                }
            return newSelectedCharRange;
            }
            
    else if ((rightpar == 0x007B) || (rightpar == 0x0028) || (rightpar == 0x005B)) {
            j = i;
            leftpar = rightpar;
            if (leftpar == 0x007B) 
                rightpar = 0x007D;
            else if (leftpar == 0x0028) 
                rightpar = 0x0029;
            else 
                rightpar = 0x005D;
            count = 1;
            done = NO;
            while ((i < (length - 1)) && (! done)) {
                i++;
                uchar = [textString characterAtIndex:i];
                if (uchar == leftpar)
                    count++;
                else if (uchar == rightpar)
                    count--;
                if (count == 0) {
                    done = YES;
                    replacementRange.location = j;
                    replacementRange.length = i - j + 1;
                    return replacementRange;
                    }
                }
            return newSelectedCharRange;
            }

    else return newSelectedCharRange;
*/
}

//=============================================================================
// timer methods
//=============================================================================
//-----------------------------------------------------------------------------
- (void) fixTags:(NSTimer *)timer;
//-----------------------------------------------------------------------------
{   
    NSString	*text, *tagString;
    unsigned	start, end, irrelevant;
    NSRange	myRange, nameRange;
    unsigned	length, index;
    int		theChar;
    // added by S. Zenitani Jan 25, 2003
    unsigned	lineNumber;
    NSMenuItem *newItem;
    // end add

    if (!fileIsTex) return;
     
    text = [textView string];
    length = [text length];
    index = tagLocation + 10000;
    lineNumber = tagLocationLine; // added
    myRange.location = tagLocation;
    myRange.length = 1;
    
    while ((myRange.location < length) && (myRange.location < index)) { 
        [text getLineStart: &start end: &end contentsEnd: &irrelevant forRange: myRange];
        myRange.location = end;
        lineNumber++;
        
        if ((start + 3) < end) {
            theChar = [text characterAtIndex: start];
            
            if (theChar == 0x0025) {
             
                theChar = [text characterAtIndex: (start + 1)];
                if (theChar == 0x003a) {
                    nameRange.location = start + 2;
                    nameRange.length = (end - start - 2);
                    tagString = [text substringWithRange: nameRange];
                    // [tags addItemWithTitle: tagString];
                    [tags addItemWithTitle: @""];
		    newItem = [tags lastItem];
                    [newItem setAction: @selector(doTag:)];
                    [newItem setTarget: self];
                    [newItem setTag: lineNumber];
                    [newItem setTitle: tagString];
                    }
                    // If an item with the name title already exists in the menu,
                    // it will be overwrited by addItemWithTitle. -- S. Zenitani Jan 25, 2003
                }
                
                /* code by Anton Leuski */
                else if ((theChar == texChar) &&  ([SUD boolForKey: TagSectionsKey])) {
					
                    unsigned	i;
                    for(i = 0; i < [kTaggedTeXSections count]; ++i) {
                        NSString* tag = [kTaggedTeXSections objectAtIndex:i];
                        nameRange.location	= start;
                        nameRange.length	= [tag length];
                        /* change by Koch to fix tag bug in 1.16 and 1.17 */
                        if ((start + nameRange.length) < end)
                            tagString = [text substringWithRange: nameRange];
                        else
                            tagString = nil;
                        if ((tagString != nil) && ([tagString isEqualToString:tag])) {
                            nameRange.location = start + [tag length];
                            nameRange.length = (end - start - [tag length]);
                            tagString = [NSString stringWithString:
                                [kTaggedTagSections objectAtIndex:i]];
                            tagString = [tagString stringByAppendingString: 
                            [text substringWithRange: nameRange]];
                            [tags addItemWithTitle: @""];
                            newItem = [tags lastItem];
                            [newItem setAction: @selector(doTag:)];
                            [newItem setTarget: self];
                            [newItem setTag: lineNumber];
                            [newItem setTitle: tagString];
                            }
                        }
					
                }
            }
        }
        tagLocation = myRange.location;
        tagLocationLine = lineNumber;
        if (tagLocation >= length) 
        {
            [tagTimer invalidate];
            [tagTimer release];
            tagTimer = nil;
        }
    
}

// I was plagued with index out of range errors in fixColor. I think they are gone now, but as a precaution
// I always test for them. 
void report(NSString *itest)
{ 
//    NSLog(itest);
}


// This is the main syntax coloring routine, used for everything except opening documents

- (void)fixColor: (unsigned)from : (unsigned)to
{
    NSRange			colorRange, newRange, newRange1, lineRange, wordRange;
    NSString			*textString;
    NSColor			*regularColor, *previousColor;
    long			length, location, final;
    unsigned			start1, end1;
    int				theChar, previousChar, aChar, i;
    BOOL			found;
    unsigned			end;
    unsigned long		itest;
    NSMutableAttributedString 	*myAttribString;
    NSDictionary		*myAttributes;

    if ((! [SUD boolForKey:SyntaxColoringEnabledKey]) || (! fileIsTex)) return;
    
    regularColor = [NSColor blackColor];
 
    textString = [textView string];
    if (textString == nil) return;
    length = [textString length];
    if (length == 0) return;

    if (returnline) {
        colorRange.location = from + 1;
        colorRange.length = 0;
        }
    
    else {

// This is an attempt to be safe.
// However, it should be fine to set colorRange.location = from and colorRange.length = (to - from) 
    if (from < length)
        colorRange.location = from;
    else
        colorRange.location = length - 1;
        
    if (to < length)
        colorRange.length = to - colorRange.location;
    else
        colorRange.length = length - colorRange.location;
    }

//   if ([SUD boolForKey:FastColoringKey]) 
   {
// We try to color simple character changes directly.
   
// Look first at backspaces over anything except a comment character or line feed
    if (fastColor && (colorRange.length == 0)) {
        [textString getLineStart:&start1 end:&end1 contentsEnd:&end forRange:colorRange];
        if (fastColorBackTeX) {
            wordRange.location = colorRange.location;
            wordRange.length = end - wordRange.location;
            i = colorRange.location + 1;
            found = NO;
            while ((i <= end) && (! found)) {
            itest = i; if ((itest < 0) || (itest >= length)) {report(@"bug1"); return;}
            aChar = [textString characterAtIndex: i];
            if (! isText1(aChar)) {
                found = YES;
                wordRange.length = i - wordRange.location;
                }
            i++;
            }

            [textView setTextColor: regularColor range: wordRange];
            
            fastColor = NO;
            fastColorBackTeX = NO;
            return;
            }
        else if (colorRange.location > start1) {
            newRange.location = colorRange.location - 1;
            newRange.length = 1;
            myAttribString = [[[NSMutableAttributedString alloc] initWithAttributedString:[textView attributedSubstringFromRange: newRange]] autorelease];
            myAttributes = [myAttribString attributesAtIndex: 0 effectiveRange: NULL];
            previousColor = [myAttributes objectForKey:NSForegroundColorAttributeName];
            if (previousColor == commandColor) { //color rest of word blue
                wordRange.location = colorRange.location;
                wordRange.length = end - wordRange.location;
                i = colorRange.location;
                found = NO;
                while ((i <= end) && (! found)) {
                    itest = i; if ((itest < 0) || (itest >= length)) {report(@"bug2"); return;}
                    aChar = [textString characterAtIndex: i];
                    if (! isText1(aChar)) {
                        found = YES;
                        wordRange.length = i - wordRange.location;
                        }
                    i++;
                    }
                [textView setTextColor: commandColor range: wordRange];
                }
            else if (previousColor == commentColor) { //color rest of line red
                newRange.location = colorRange.location;
                newRange.length = (end - colorRange.location);
                [textView setTextColor: commentColor range: newRange];
                }
            fastColor = NO;
            fastColorBackTeX = NO;
            return;
            }
        fastColor = NO;
        fastColorBackTeX = NO;
        }
        
    fastColorBackTeX = NO;

// Look next at cases when a single character is added
    if ( fastColor && (colorRange.length == 1) && (colorRange.location > 0)) {
        itest = colorRange.location; if ((itest < 0) || (itest >= length)) {report(@"bug3"); return;}
        theChar = [textString characterAtIndex: colorRange.location];
        itest = (colorRange.location - 1); if ((itest < 0) || (itest >= length)) {report(@"bug4"); return;}
        previousChar = [textString characterAtIndex: (colorRange.location - 1)];
        newRange.location = colorRange.location - 1;
        newRange.length = colorRange.length;
        myAttribString = [[[NSMutableAttributedString alloc] initWithAttributedString:[textView attributedSubstringFromRange: newRange]] autorelease];
        myAttributes = [myAttribString attributesAtIndex: 0 effectiveRange: NULL];
        previousColor = [myAttributes objectForKey:NSForegroundColorAttributeName];
        if ((!isText1(theChar)) && (previousChar == texChar)) {
            if (previousColor == commentColor)
                [textView setTextColor: commentColor range: colorRange];
            else if (previousColor == commandColor) {
            	[textView setTextColor: commandColor range: colorRange];
                [textString getLineStart:&start1 end:&end1 contentsEnd:&end forRange:colorRange];
                wordRange.location = colorRange.location + 1;
                wordRange.length = end - wordRange.location;
                i = colorRange.location + 1;
                found = NO;
                while ((i < end) && (! found)) {
                    itest = i; if ((itest < 0) || (itest >= length)) {report(@"bug5"); return;}
                    aChar = [textString characterAtIndex: i];
                    if (! isText1(aChar)) {
                        found = YES;
                        wordRange.length = i - wordRange.location;
                        }
                    i++;
                    }
                // rest of word black; (word range is range AFTER this char to end of word)
                [textView setTextColor: regularColor range: wordRange];
                }
            else
                [textView setTextColor: commandColor range: colorRange];
            fastColor = NO;
            return;
            }
        if ((theChar == 0x007b) || (theChar == 0x007d) || (theChar == 0x0024)) {
            if (previousColor == commentColor)
                [textView setTextColor: commentColor range: colorRange];
            else if (previousColor == commandColor) {
            	[textView setTextColor: markerColor range: colorRange];
                [textString getLineStart:&start1 end:&end1 contentsEnd:&end forRange:colorRange];
                wordRange.location = colorRange.location + 1;
                wordRange.length = end - wordRange.location;
                i = colorRange.location + 1;
                found = NO;
                while ((i < end) && (! found)) {
                    itest = i; if ((itest < 0) || (itest >= length)) {report(@"bug6"); return;}
                    aChar = [textString characterAtIndex: i];
                    if (! isText1(aChar)) {
                        found = YES;
                        wordRange.length = i - wordRange.location;
                        }
                    i++;
                    }
                // rest of word black; (word range is range AFTER this char to end of word)
                [textView setTextColor: regularColor range: wordRange];
                }
            else
                [textView setTextColor: markerColor range: colorRange];
            fastColor = NO;
            return;
            }
        if (theChar == 0x0020) {
            if (previousColor == commentColor)
                [textView setTextColor: commentColor range: colorRange];
            else if (previousColor == markerColor)
                [textView setTextColor: regularColor range: colorRange];
            else if (previousColor == commandColor) {
                // rest of word black; (wordRange is range to end of word INCLUDING this char)
                [textString getLineStart:&start1 end:&end1 contentsEnd:&end forRange:colorRange];
                wordRange.location = colorRange.location;
                wordRange.length = end - wordRange.location;
                i = colorRange.location + 1;
                found = NO;
                while ((i < end) && (! found)) {
                    itest = i; if ((itest < 0) || (itest >= length)) {report(@"bug7"); return;}
                    aChar = [textString characterAtIndex: i];
                    if (! isText1(aChar)) {
                        found = YES;
                        wordRange.length = i - wordRange.location;
                        }
                    i++;
                    }

                [textView setTextColor: regularColor range: wordRange];
                }
            else
                [textView setTextColor: regularColor range: colorRange];
            fastColor = NO;
            return;
            }
        if (theChar == 0x0025) {
            [textString getLineStart:&start1 end:&end1 contentsEnd:&end forRange:colorRange];
            lineRange.location = colorRange.location;
            lineRange.length = end - colorRange.location;
            [textView setTextColor: commentColor range: lineRange];
            fastColor = NO;
            return;
            }
        if (theChar == texChar) {
            if (previousColor == commentColor)
                [textView setTextColor: commentColor range: colorRange];
            else {
                // word Range is rest of word, including this
                [textString getLineStart:&start1 end:&end1 contentsEnd:&end forRange:colorRange];
                wordRange.location = colorRange.location;
                wordRange.length = end - wordRange.location;
                i = colorRange.location + 1;
                found = NO;
                while ((i < end) && (! found)) {
                    itest = i; if ((itest < 0) || (itest >= length)) {report(@"bug8"); return;}
                    aChar = [textString characterAtIndex: i];
                    if (! isText1(aChar)) {
                        found = YES;
                        wordRange.length = i - wordRange.location;
                        }
                    i++;
                    }

                [textView setTextColor: commandColor range: wordRange];
                }
            fastColor = NO;
            return;
            }
            
        if ((theChar != texChar) && (theChar != 0x007b) && (theChar != 0x007d) && (theChar != 0x0024) &&
            (theChar != 0x0025) && (theChar != 0x0020) && (previousChar != 0x007d) && (previousChar != 0x007b)
            && (previousChar != 0x0024) ) {
                if ((previousColor == commandColor) && (! isText1(theChar))) {
                    [textString getLineStart:&start1 end:&end1 contentsEnd:&end forRange:colorRange];
                    wordRange.location = colorRange.location;
                    wordRange.length = end - wordRange.location;
                    i = colorRange.location + 1;
                    found = NO;
                    while ((i <= end) && (! found)) {
                        itest = i; if ((itest < 0) || (itest >= length)) {report(@"bug9"); return;}
                        aChar = [textString characterAtIndex: i];
                        if (! isText1(aChar)) {
                            found = YES;
                            wordRange.length = i - wordRange.location;
                            }
                        i++;
                        }

                    [textView setTextColor: regularColor range: wordRange];
                     }
                else if ((previousColor == commandColor) && (! isText1(previousChar)) && (previousChar != texChar)) {
                    [textString getLineStart:&start1 end:&end1 contentsEnd:&end forRange:colorRange];
                    wordRange.location = colorRange.location;
                    wordRange.length = end - wordRange.location;
                    i = colorRange.location + 1;
                    found = NO;
                    while ((i < end) && (! found)) {
                        itest = i; if ((itest < 0) || (itest >= length)) {report(@"bug10"); return;}
                        aChar = [textString characterAtIndex: i];
                        if (! isText1(aChar)) {
                            found = YES;
                            wordRange.length = i - wordRange.location;
                            }
                        i++;
                        }

                    [textView setTextColor: regularColor range: wordRange];
                    }
                else if (previousChar >= 0x0020)
                    [textView setTextColor: previousColor range: colorRange];
                else
                    [textView setTextColor: regularColor range: colorRange];
                fastColor = NO;
                return;
                }
        }
        
    fastColor = NO;
}

    // If that trick fails, we work harder.
    // [[textView textStorage] beginEditing];
    [textStorage beginEditing];

    [textString getLineStart:&start1 end:&end1 contentsEnd:&end forRange:colorRange];
    location = start1;
    final = end1;

    colorRange.location = start1;
    colorRange.length = end1 - start1;
    
// The following code fixes a subtle syntax coloring bug; Koch; Jan 1, 2003
    if (start1 > 0) 
        newRange1.location = (start1 - 1);
    else
        newRange1.location = 0;
    if (start1 > 0)
        newRange1.length = end1 - start1 + 1;
    else
        newRange1.length = end1 - start1;
    [textView setTextColor: regularColor range: newRange1];
// End of fix

   [textView setTextColor: regularColor range: colorRange]; 
    
    while (location < final) {
            itest = location; if ((itest < 0) || (itest >= length)) {report(@"bug11"); return;}
            theChar = [textString characterAtIndex: location];
            
             if ((theChar == 0x007b) || (theChar == 0x007d) || (theChar == 0x0024)) {
                colorRange.location = location;
                colorRange.length = 1;
                [textView setTextColor: markerColor range: colorRange];
                colorRange.location = colorRange.location + colorRange.length - 1;
                colorRange.length = 0;
               [textView setTextColor: regularColor range: colorRange];
                location++;
                }
                
             else if (theChar == 0x0025) {
                colorRange.location = location;
                colorRange.length = 0;
                [textString getLineStart:NULL end:NULL contentsEnd:&end forRange:colorRange];
                colorRange.length = (end - location);
                [textView setTextColor: commentColor range: colorRange];
                colorRange.location = colorRange.location + colorRange.length - 1;
                colorRange.length = 0;
               [textView setTextColor: regularColor range: colorRange];
                location = end;
                }
                
             else if (theChar == texChar) {
                colorRange.location = location;
                colorRange.length = 1;
                location++;
               itest = location; if (location < final) if ((itest < 0) || (itest >= length)) {report(@"bug12"); return;}
               if ((location < final) && (!isText1([textString characterAtIndex: location]))) {
                    location++;
                    colorRange.length = location - colorRange.location;
                    }
                else {
                    itest = location; if (location < final) if ((itest < 0) || (itest >= length)) {report(@"bug13"); return;}
                    while ((location < final) && (isText1([textString characterAtIndex: location]))) {
                    location++;
                    colorRange.length = location - colorRange.location;
                    itest = location; if (location < final) if ((itest < 0) || (itest >= length)) {report(@"bug14"); return;}
                    }}
                [textView setTextColor: commandColor range: colorRange];
                colorRange.location = location;
                colorRange.length = 0;
               [textView setTextColor: regularColor range: colorRange];
                }

            else
                location++;
            }
         // [[textView textStorage] endEditing];
         [textStorage endEditing];


       
}




//-----------------------------------------------------------------------------
- (void)reColor:(NSNotification *)notification;
//-----------------------------------------------------------------------------
{
    NSString	*textString;
    long	length;
    NSRange	theRange;
    
    if (syntaxColoringTimer != nil) {
        [syntaxColoringTimer invalidate];
        [syntaxColoringTimer release];
        syntaxColoringTimer = nil;
        }
        
    textString = [textView string];
    length = [textString length];
    if ([SUD boolForKey:SyntaxColoringEnabledKey]) 
        [self fixColor :0 :length];
    else {
        theRange.location = 0;
        theRange.length = length;
        [textView setTextColor: [NSColor blackColor] range: theRange];
        }
        
    
    // colorLocation = 0;
    // syntaxColoringTimer = [[NSTimer scheduledTimerWithTimeInterval: COLORTIME target:self selector:@selector(fixColor1:) 	userInfo:nil repeats:YES] retain];
}

//=============================================================================
// nofification methods
//=============================================================================
- (void)checkATaskStatus:(NSNotification *)aNotification 
{
    NSString		*imagePath;
#ifndef ROOTFILE
    NSString		*projectPath, *nameString;
#endif
    NSDictionary	*myAttributes;
    NSDate		*endDate;
#ifndef MITSU_PDF
    NSRect		topLeftRect;
    NSPoint		topLeftPoint;
#endif
    int			status;
    
    [outputText setSelectable: YES];

    if (([aNotification object] == bibTask) || ([aNotification object] == indexTask) || ([aNotification object] == metaFontTask)) 
    {
        if (inputPipe == [[aNotification object] standardInput]) 
        {
            [outputPipe release];
            [writeHandle closeFile];
            [inputPipe release];
            inputPipe = 0;
            if ([aNotification object] == bibTask) {
                [bibTask terminate];
                [bibTask release];
                bibTask = nil;
                }
            else if ([aNotification object] == indexTask) {
                [indexTask terminate];
                [indexTask release];
                indexTask = nil;
                }
            else if ([aNotification object] == metaFontTask) {
                [metaFontTask terminate];
                [metaFontTask release];
                metaFontTask = nil;
                }
        }
    }
    
    if ([aNotification object] != texTask) 
        return;

    if (inputPipe == [[aNotification object] standardInput]) 
    {
        status = [[aNotification object] terminationStatus];
    
        if ((status == 0) || (status == 1))  
        {
#ifndef ROOTFILE
            projectPath = [[[self fileName] stringByDeletingPathExtension] stringByAppendingPathExtension:@"texshop"];
            if ([[NSFileManager defaultManager] fileExistsAtPath: projectPath]) 
            {
                NSString *projectRoot = [NSString stringWithContentsOfFile: projectPath];
                if ([projectRoot isAbsolutePath]) {
                    nameString = [NSString stringWithString:projectRoot];
                }
                else {
                    nameString = [[self fileName] stringByDeletingLastPathComponent];
                    nameString = [[nameString stringByAppendingString:@"/"] 
                        stringByAppendingString: [NSString stringWithContentsOfFile: projectPath]];
                    nameString = [nameString stringByStandardizingPath];
                }
                imagePath = [[nameString stringByDeletingPathExtension] stringByAppendingPathExtension:@"pdf"];
            }
            else
#endif
                imagePath = [[[self fileName] stringByDeletingPathExtension] stringByAppendingPathExtension:@"pdf"];

            if ([[NSFileManager defaultManager] fileExistsAtPath: imagePath]) 
            {
                myAttributes = [[NSFileManager defaultManager] fileAttributesAtPath: imagePath traverseLink:NO];
                endDate = [myAttributes objectForKey:NSFileModificationDate];
                if ((startDate == nil) || ! [startDate isEqualToDate: endDate]) 
                {
                    texRep = [[NSPDFImageRep imageRepWithContentsOfFile: imagePath] retain]; 
                    if (texRep) 
                    {
                        /* [pdfWindow setTitle:[[[[self fileName] lastPathComponent] stringByDeletingPathExtension] 					stringByAppendingPathExtension:@"pdf"]]; */
                        [pdfWindow setTitle: [imagePath lastPathComponent]];
                        [pdfView setImageRep: texRep];
#ifndef MITSU_PDF
                        if (startDate == nil) 
                        {
                            topLeftRect = [texRep bounds];
                            topLeftPoint.x = topLeftRect.origin.x;
                            topLeftPoint.y = topLeftRect.origin.y + topLeftRect.size.height - 1;
                            [pdfView scrollPoint: topLeftPoint];
                        }
#endif
                        
                        [pdfView setNeedsDisplay:YES];
                        [pdfWindow makeKeyAndOrderFront: self];
                    }
                 }
            }
            [texTask terminate];
            [texTask release];
          }
            
        [outputPipe release];
        [writeHandle closeFile];
        [inputPipe release];
        inputPipe = 0;
        texTask = nil;
    }
}

- (void) checkPrefClose: (NSNotification *)aNotification
{
    int	finalResult;
    
    if (([aNotification object] == projectPanel) ||
        ([aNotification object] == requestWindow) ||
        ([aNotification object] == linePanel) ||
        ([aNotification object] == printRequestPanel)) 
    {
        finalResult = myPrefResult;
        if (finalResult == 2) finalResult = 0;
        [NSApp stopModalWithCode: finalResult];
    }
}

- (void) writeTexOutput: (NSNotification *)aNotification
{
    NSString		*newOutput, *numberOutput, *searchString, *tempString;
    NSData		*myData;
    NSRange		myRange, lineRange, searchRange;
    int			error, tag;
    unsigned int	myLength;
    unsigned		start, end, irrelevant;
    NSStringEncoding	theEncoding;
    
    NSFileHandle *myFileHandle = [aNotification object];
    if (myFileHandle == readHandle) 
    {
        myData = [[aNotification userInfo] objectForKey:@"NSFileHandleNotificationDataItem"];
        if ([myData length]) 
        {
            tag = [[EncodingSupport sharedInstance] tagForEncodingPreference];
            theEncoding = [[EncodingSupport sharedInstance] stringEncodingForTag: tag];
            newOutput = [[NSString alloc] initWithData: myData encoding: theEncoding];
        
/*
            if ([[SUD stringForKey:EncodingKey] isEqualToString:@"IsoLatin"])
                newOutput = [[NSString alloc] initWithData: myData 
                    encoding: NSISOLatin1StringEncoding]; 
            else if ([[SUD stringForKey:EncodingKey] isEqualToString:@"IsoLatin2"])
                newOutput = [[NSString alloc] initWithData: myData 
                    encoding: NSISOLatin2StringEncoding];
            else if ([[SUD stringForKey:EncodingKey] isEqualToString:@"MacJapanese"])
                newOutput = [[NSString alloc] initWithData: myData 
                    encoding: CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingMacJapanese)];
            // S. Zenitani Dec 13, 2002:
            else if ([[SUD stringForKey:EncodingKey] isEqualToString:@"DOSJapanese"])
                newOutput = [[NSString alloc] initWithData: myData 
                    encoding: CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingDOSJapanese)];
            else if ([[SUD stringForKey:EncodingKey] isEqualToString:@"EUC_JP"])
                newOutput = [[NSString alloc] initWithData: myData 
                    encoding: CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingEUC_JP)];
            // --- end
            else if ([[SUD stringForKey:EncodingKey] isEqualToString:@"JISJapanese"])
                newOutput = [[NSString alloc] initWithData: myData 
                    encoding: CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingISO_2022_JP)];
            else if ([[SUD stringForKey:EncodingKey] isEqualToString:@"MacKorean"])
                newOutput = [[NSString alloc] initWithData: myData 
                    encoding: CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingMacKorean)];
            else if ([[SUD stringForKey:EncodingKey] isEqualToString:@"UTF-8 Unicode"])
                newOutput = [[NSString alloc] initWithData: myData 
                    encoding: NSUTF8StringEncoding];
            else if ([[SUD stringForKey:EncodingKey] isEqualToString:@"Standard Unicode"])
                newOutput = [[NSString alloc] initWithData: myData 
                    encoding: NSUnicodeStringEncoding];
            else if ([[SUD stringForKey:EncodingKey] isEqualToString:@"Mac Cyrillic"])
                newOutput = [[NSString alloc] initWithData: myData 
                    encoding: CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingMacCyrillic)];
            else if ([[SUD stringForKey:EncodingKey] isEqualToString:@"DOS Cyrillic"])
                newOutput = [[NSString alloc] initWithData: myData 
                    encoding: CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingDOSCyrillic)];
            else if ([[SUD stringForKey:EncodingKey] isEqualToString:@"DOS Russian"])
                newOutput = [[NSString alloc] initWithData: myData 
                    encoding: CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingDOSRussian)];
            else if ([[SUD stringForKey:EncodingKey] isEqualToString:@"Windows Cyrillic"])
                newOutput = [[NSString alloc] initWithData: myData 
                    encoding: CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingWindowsCyrillic)];
            else if ([[SUD stringForKey:EncodingKey] isEqualToString:@"KOI8_R"])
                newOutput = [[NSString alloc] initWithData: myData 
                    encoding: CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingKOI8_R)];
            else
                newOutput = [[NSString alloc] initWithData: myData 
                    encoding: NSMacOSRomanStringEncoding];
*/
            if ((makeError) && ([newOutput length] > 2) && (errorNumber < NUMBEROFERRORS)) 
            {
                myLength = [newOutput length];
                searchString = @"l.";
                lineRange.location = 0;
                lineRange.length = 1;
                while (lineRange.location < myLength) 
                {
                    [newOutput getLineStart: &start end: &end contentsEnd: &irrelevant forRange: lineRange];
                    lineRange.location = end;
                    searchRange.location = start;
                    searchRange.length = end - start;
                    tempString = [newOutput substringWithRange: searchRange];
                    myRange = [tempString rangeOfString: searchString];
                    if ((myRange.location = 1) && (myRange.length > 0)) 
                    {
                        numberOutput = [tempString substringFromIndex:(myRange.location + 1)];
                        error = [numberOutput intValue];
                        if ((error > 0) && (errorNumber < NUMBEROFERRORS)) 
                        {
                            errorLine[errorNumber] = error;
                            errorNumber++;
                            [outputWindow makeKeyAndOrderFront: self];
                        }
                    }
                }
            }

            typesetStart = YES;
            
            [outputText replaceCharactersInRange: [outputText selectedRange] withString: newOutput];
            [outputText scrollRangeToVisible: [outputText selectedRange]];
            [newOutput release];
            [readHandle readInBackgroundAndNotify];
        }
    }
}

- (NSDictionary *)fileAttributesToWriteToFile:(NSString *)fullDocumentPath ofType:(NSString *)documentTypeName saveOperation:(NSSaveOperationType)saveOperationType
{
    NSDictionary	*myDictionary;
    NSMutableDictionary	*aDictionary;
    NSNumber		*myNumber;
    
    myDictionary = [super fileAttributesToWriteToFile: fullDocumentPath ofType: documentTypeName
                    saveOperation: saveOperationType];
    aDictionary = [NSMutableDictionary dictionaryWithDictionary: myDictionary];
    myNumber = [NSNumber numberWithLong:'TEXT'];
    [aDictionary setObject: myNumber forKey: NSFileHFSTypeCode];
    myNumber = [NSNumber numberWithLong:'TeXs'];
    [aDictionary setObject: myNumber forKey: NSFileHFSCreatorCode]; 
    return aDictionary;
}

// The code below was slightly modified by Martin Heusse to count trailing spaces; see below

/*
// Code by Nicol�s Ojeda B�r 
- (int) textViewCountTabs: (NSTextView *) aTextView
{
    int startLocation = [aTextView selectedRange].location - 1, tabCount = 0;

    if (startLocation < 0)
    return 0;

    while ([[aTextView string] characterAtIndex: startLocation] != '\n') {
    
        if ([[aTextView string] characterAtIndex: startLocation --] != '\t')
            tabCount = 0;
        else
            ++ tabCount;
            
        if (startLocation < 0)
            break;
    }

    return tabCount;
}

// Code by Nicol�s Ojeda B�r
- (BOOL) textView: (NSTextView *) aTextView doCommandBySelector: (SEL)
aSelector
{
    if (aSelector == @selector (insertNewline:)) {
    int n, indent = [self textViewCountTabs: textView];

    [aTextView insertNewline: self];

    for (n = 0; n < indent; ++ n)
        [aTextView insertText: @"\t"];

    return YES;
    }

    return NO;
}
*/

// Code by Nicol�s Ojeda B�r, modified by Martin Heusse
- (int) textViewCountTabs: (NSTextView *) aTextView andSpaces: (int *) spaces
{
    int startLocation = [aTextView selectedRange].location - 1, tabCount = 0;
    unichar currentChar;

    if (startLocation < 0)
        return 0;

    while ((currentChar = [[aTextView string] characterAtIndex: startLocation]) != '\n') {

        if (currentChar != '\t' && currentChar != ' '){
            tabCount = 0;
            *spaces = 0;
        }
        else{
            if (currentChar == '\t')
                ++ tabCount;

            if (currentChar == ' ' && tabCount == 0)
                ++ *spaces;
        }
        startLocation --;
        if (startLocation < 0)
            break;
    }

    return tabCount;
}

// Code by Nicol�s Ojeda B�r, slightly modified by Martin Heusse
- (BOOL) textView: (NSTextView *) aTextView doCommandBySelector: (SEL)
    aSelector
{
  
    if (aSelector == @selector (insertNewline:))
        {
        int n, indentTab, indentSpace = 0;

        indentTab = [self textViewCountTabs: textView andSpaces: &indentSpace];
        [aTextView insertNewline: self];

        for (n = 0; n < indentTab; ++ n)
            [aTextView insertText: @"\t"];
        for (n = 0; n < indentSpace; ++ n)
            [aTextView insertText: @" "];

        return YES;
        }

    return NO;
}


//-----------------------------------------------------------------------------
- (void) fixTyping: (id) theDictionary;
//-----------------------------------------------------------------------------

{
    NSRange		oldRange;
    NSString		*oldString, *newString;
    NSUndoManager	*myManager;
    NSMutableDictionary	*myDictionary;
    NSNumber		*theLocation, *theLength;
    unsigned		from, to;
    
    oldRange.location = [[theDictionary objectForKey: @"oldLocation"] unsignedIntValue];
    oldRange.length = [[theDictionary objectForKey: @"oldLength"] unsignedIntValue];
    newString = [theDictionary objectForKey: @"oldString"];
    oldString = [[textView string] substringWithRange: oldRange];
    [textView replaceCharactersInRange: oldRange withString: newString];

    myManager = [textView undoManager];
    myDictionary = [NSMutableDictionary dictionaryWithCapacity: 3];
    theLocation = [NSNumber numberWithInt: oldRange.location];
    theLength = [NSNumber numberWithInt: [newString length]];
    [myDictionary setObject: oldString forKey: @"oldString"];
    [myDictionary setObject: theLocation forKey: @"oldLocation"];
    [myDictionary setObject: theLength forKey: @"oldLength"];
    [myManager registerUndoWithTarget:self selector:@selector(fixTyping:) object: myDictionary];
    [myManager setActionName:NSLocalizedString(@"Typing", @"Typing")];
    from = oldRange.location;
    to = from + [newString length];
    [self fixColor: from :to];
    [self setupTags];

}

/* New Code by Max Horn, to activate #SEL# and #INS# in Panel Strings */
- (void)doCompletion:(NSNotification *)notification
{
// mitsu 1.29 (T2) use "insertSpecial:undoKey:" 
    NSWindow		*activeWindow;
    activeWindow = [[TSWindowManager sharedInstance] activeDocumentWindow];
    if ((activeWindow != nil) && (activeWindow == [self textWindow])) 
	{
		[self insertSpecial: [notification object] 
					undoKey: NSLocalizedString(@"LaTeX Panel", @"LaTeX Panel")];
		//[textView insertSpecial: [notification object] 
		//			undoKey: NSLocalizedString(@"LaTeX Panel", @"LaTeX Panel")];
	}
        
// old code was:
/*
    NSRange			oldRange;
    NSRange			searchRange;
    NSWindow		*activeWindow;
    NSMutableString	*newString;
    NSString		*oldString;
    unsigned		from, to;
    NSUndoManager	*myManager;
    NSMutableDictionary	*myDictionary;
    NSNumber		*theLocation, *theLength;

    activeWindow = [[TSWindowManager sharedInstance] activeDocumentWindow];
    if ((activeWindow != nil) && (activeWindow == [self textWindow])) {
        // Determine the curent selection range & text
        oldRange = [textView selectedRange];
        oldString = [[textView string] substringWithRange: oldRange];

        // Fetch the replacement text
        newString = [[[notification object] mutableCopy] autorelease];

        // Substitute all occurances of #SEL# with the original text
        searchRange.location = 0;
        while (searchRange.location != NSNotFound) {
            searchRange.length = [newString length] - searchRange.location;
            searchRange = [newString rangeOfString:@"#SEL#" options:NSLiteralSearch range:searchRange];
            if (searchRange.location != NSNotFound) {
                [newString replaceCharactersInRange:searchRange withString:oldString];
                searchRange.location += oldRange.length;
            }
        }

        // Now search for #INS#, remember its position, and remove it. We will
        // Later position the insertion mark there. Defaults to end of string.
        searchRange = [newString rangeOfString:@"#INS#" options:NSLiteralSearch];
        if (searchRange.location != NSNotFound)
            [newString replaceCharactersInRange:searchRange withString:@""];

        // Insert the new text
// changed by mitsu --(E) LaTex panel with yen; conversion backslash<->yen is handled by insertText
//        [textView insertText: newString]; // this was late changed by mitsu to
          if (shouldFilter == filterMacJ)
                newString = filterBackslashToYen(newString);
          [textView replaceCharactersInRange:oldRange withString:newString];

// original was:
//       [textView replaceCharactersInRange:oldRange withString:newString];
// end change
        
        // Create & register an undo action
        myManager = [textView undoManager];
        myDictionary = [NSMutableDictionary dictionaryWithCapacity: 3];
        theLocation = [NSNumber numberWithUnsignedInt: oldRange.location];
        theLength = [NSNumber numberWithUnsignedInt: [newString length]];
        [myDictionary setObject: oldString forKey: @"oldString"];
        [myDictionary setObject: theLocation forKey: @"oldLocation"];
        [myDictionary setObject: theLength forKey: @"oldLength"];
        [myManager registerUndoWithTarget:self selector:@selector(fixTyping:) object: myDictionary];
        [myManager setActionName:NSLocalizedString(@"Typing", @"Typing")];
        from = oldRange.location;
        to = from + [newString length];
        [self fixColor:from :to];
        [self setupTags];

        // Place insertion mark
        if (searchRange.location != NSNotFound)
        {
            searchRange.location += oldRange.location;
            searchRange.length = 0;
            [textView setSelectedRange:searchRange];
        }
    }
*/
}

- (void) changeAutoComplete: sender
{
    doAutoComplete = ! doAutoComplete;
    [self fixAutoMenu];
}

- (void) fixMacroMenu;
{
/*
    if (whichEngine == 6)
        macroType = 1;
    else
        macroType = 0;
*/
    macroType = whichEngine;
    [[MacroMenuController sharedInstance] reloadMacros: self];
}

- (void) fixAutoMenu
{
      [autoCompleteButton setState: doAutoComplete];
      NSEnumerator* enumerator = [[[textWindow toolbar] items] objectEnumerator];
      id anObject;
      while (anObject = [enumerator nextObject]) {
        if ([[anObject itemIdentifier] isEqual: @"AutoComplete"]) {
            if (doAutoComplete)
//                [[[[anObject menuFormRepresentation] submenu] itemAtIndex:0] setTitle: NSLocalizedString(@"Turn off", @"Turn off")];
                  [[[[anObject menuFormRepresentation] submenu] itemAtIndex:0] setState: NSOnState];
            else
//                [[[[anObject menuFormRepresentation] submenu] itemAtIndex:0] setTitle: NSLocalizedString(@"Turn on", @"Turn on")];
                  [[[[anObject menuFormRepresentation] submenu] itemAtIndex:0] setState: NSOffState];
            }
        }
}

//-----------------------------------------------------------------------------
- (void)changePrefAutoComplete:(NSNotification *)notification;
//-----------------------------------------------------------------------------
{
    doAutoComplete = [SUD boolForKey:AutoCompleteEnabledKey];
    [autoCompleteButton setState: doAutoComplete];
}



// The code below is copied directly from Apple's TextEdit Example 

static NSArray *tabStopArrayForFontAndTabWidth(NSFont *font, unsigned tabWidth) {
    static NSMutableArray *array = nil;
    static float currentWidthOfTab = -1;
    float charWidth;
    float widthOfTab;
    unsigned i;

    if ([font glyphIsEncoded:(NSGlyph)' ']) {
        charWidth = [font advancementForGlyph:(NSGlyph)' '].width;
    } else {
        charWidth = [font maximumAdvancement].width;
    }
    widthOfTab = (charWidth * tabWidth);

    if (!array) {
        array = [[NSMutableArray allocWithZone:NULL] initWithCapacity:100];
    }

    if (widthOfTab != currentWidthOfTab) {
        [array removeAllObjects];
        for (i = 1; i <= 100; i++) {
            NSTextTab *tab = [[NSTextTab alloc] initWithType:NSLeftTabStopType location:widthOfTab * i];
            [array addObject:tab];
            [tab release];
        }
        currentWidthOfTab = widthOfTab;
    }

    return array;
}

// The code below is a modification of code from Apple's TextEdit example

- (void)fixUpTabs {
    BOOL			empty = NO;
    NSRange			myRange, theRange;
    unsigned			tabWidth;
    NSParagraphStyle 		*paraStyle;
    NSMutableParagraphStyle 	*newStyle;
    NSFont			*font = nil;
    NSData			*fontData;

//     NSTextStorage *textStorage = [textView textStorage];
    NSString *string = [textStorage string];
    
    if ([SUD boolForKey:SaveDocumentFontKey] == NO) {
        font = [NSFont userFontOfSize:12.0];
        }
    else {
        fontData = [SUD objectForKey:DocumentFontKey];
        if (fontData != nil) {
            font = [NSUnarchiver unarchiveObjectWithData:fontData];
            [textView setFont:font];
            }
        else
            font = [NSFont userFontOfSize:12.0];
        }

    // I cannot figure out how to set the tabs if there is no text, so in that
    // case I insert text and later remove it; Koch, 11/28/2002
    if ([string length] == 0) {
        empty = YES;
        myRange.location = 0; myRange.length = 0;
        // empty files have a space, but the cursor is at the start
        // [[textView textStorage] replaceCharactersInRange: myRange withString:@" "];
        [textStorage replaceCharactersInRange: myRange withString:@" "]; 
        
        }
        
    
    tabWidth = [SUD integerForKey: tabsKey];
            
    NSArray *desiredTabStops = tabStopArrayForFontAndTabWidth(font, tabWidth);
 
    paraStyle = [NSParagraphStyle defaultParagraphStyle];
    newStyle = [paraStyle mutableCopyWithZone:[textStorage zone]];
    [newStyle setTabStops:desiredTabStops];
    theRange.location = 0; theRange.length = [string length];
    [textStorage addAttribute:NSParagraphStyleAttributeName value:newStyle range: theRange];
    [newStyle release];
        
    if (empty) {
        myRange.location = 0; myRange.length = 1;
//        [[textView textStorage] replaceCharactersInRange: myRange withString:@""]; //was "\b"
        }
        
   [textView setFont:font];

}

// added by mitsu --(J) Typeset command, (D) Tags and (H) Macro
//-----------------------------------------------------------------------------
- (int)whichEngine
//-----------------------------------------------------------------------------
{
	return whichEngine;
}

//-----------------------------------------------------------------------------
- (void)resetTagsMenu:(NSNotification *)notification;
//-----------------------------------------------------------------------------
{
    [self setupTags];
}

//-----------------------------------------------------------------------------
- (void)resetMacroButton:(NSNotification *)notification;
//-----------------------------------------------------------------------------
{
    [[MacroMenuController sharedInstance] addItemsToPopupButton: macroButton];
}
// end addition


// end addition

// added by John A. Nairn
// check for linked files.
//	If %SourceDoc, typeset from there instead
//	If \input commands, save those documents if opened and changed

//-----------------------------------------------------------------------------
- (BOOL)checkMasterFile:(NSString *)theSource forTask:(int)task;
//-----------------------------------------------------------------------------
{
    NSString *home,*jobname=[[self fileName] stringByDeletingLastPathComponent];
    NSRange aRange,bRange;
    NSString *saveName;
    NSArray *wlist;
    NSEnumerator *en;
    id obj;
    NSDocumentController *dc;
    
    if (theSource == nil)
        return NO;
    
    // load home path and jobname
    home=[[self fileName] stringByDeletingLastPathComponent];
    jobname=[[[self fileName] lastPathComponent] stringByDeletingPathExtension];
    
    // see if there is a parent document
    aRange=[theSource rangeOfString:@"%SourceDoc "];
    if(aRange.location!=NSNotFound)
    {	bRange=[theSource lineRangeForRange:aRange];
        if(bRange.length>12 && aRange.location==bRange.location)
        {   saveName=[self
                decodeFile:[theSource substringWithRange:NSMakeRange(bRange.location+11,bRange.length-12)]
                homePath:home job:jobname];
            
            // is the document open?
            wlist=[NSApp orderedDocuments];
            en=[wlist objectEnumerator];
            while(obj=[en nextObject])
            {	if([[obj windowNibName] isEqualToString:@"MyDocument"])
                {   if([[obj fileName] isEqualToString:saveName]) {
                    if (obj == self)
                        return NO;
                    if (task == RootForPrinting) 
                        [obj printDocument:nil];
                    else if (task == RootForTexing)
                        {	rootDocument = obj;
                                switch(whichEngine) {
                                case TexEngine: [obj doTex:nil]; break;
                                case LatexEngine: [obj doLatex:nil]; break;
                                case ContextEngine: [obj doContext:nil]; break;
                                case MetapostEngine: [obj doMetapost:nil]; break;
                                case BibtexEngine: [obj doBibtex:nil]; break;
                                case IndexEngine: [obj doIndex:nil]; break;
                                case MetafontEngine: [obj doMetaFont:nil]; break;
                                default: NSBeginAlertSheet(@"Typesetting engine cannot be found.",
                                    nil,nil,nil,[textView window],nil,nil,nil,nil,
                                    @"Path Name: %@",saveName);
                                }
                            }
                    else if (task == RootForOpening) {
                        ;
                        }
                    return YES;
                    }
                }
            }
            
            // document not found, open document and typeset
            dc=[NSDocumentController sharedDocumentController];
            obj=[dc openDocumentWithContentsOfFile:saveName display:YES];
            if(obj) {
                if (obj == self)
                    return NO;
            	if (task == RootForPrinting)
                    [obj printDocument:nil];
                else if (task == RootForTexing){
                        rootDocument = obj;
                        switch(whichEngine) {
                            case TexEngine: [obj doTex:nil]; break;
                            case LatexEngine: [obj doLatex:nil]; break;
                            case ContextEngine: [obj doContext:nil]; break;
                            case MetapostEngine: [obj doMetapost:nil]; break;
                            case BibtexEngine: [obj doBibtex:nil]; break;
                            case IndexEngine: [obj doIndex:nil]; break;
                            case MetafontEngine: [obj doMetaFont:nil]; break;
                            default: NSBeginAlertSheet(@"Typesetting engine cannot be found.",
                                nil,nil,nil,[textView window],nil,nil,nil,nil,
                                @"Path Name: %@",saveName);
                            }
                        }
                else if (task == RootForOpening) {
                    [[obj textWindow] miniaturize:self];
                    }
                return YES;
                }
            else
            {	NSBeginAlertSheet(@"The source LaTeX document can not be found.",
                    nil,nil,nil,[textView window],nil,nil,nil,nil,
                    @"Path Name: %@",saveName);
            }
            return YES;
        }
    }
    return NO;
}

//-----------------------------------------------------------------------------
- (BOOL) checkRootFile_forTask:(int)task
//-----------------------------------------------------------------------------
{
    NSString			*projectPath, *nameString;
    NSArray 			*wlist;
    NSEnumerator 		*en;
    id 				obj;
    NSDocumentController 	*dc;



    projectPath = [[[self fileName] stringByDeletingPathExtension] stringByAppendingPathExtension:@"texshop"];
    if (![[NSFileManager defaultManager] fileExistsAtPath: projectPath]) 
        return NO;
    
    NSString *projectRoot = [NSString stringWithContentsOfFile: projectPath];
    projectRoot = [projectRoot stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if ([projectRoot length] == 0)
        return NO;
    if ([projectRoot isAbsolutePath]) 
        nameString = [NSString stringWithString:projectRoot];
    else {
        nameString = [[self fileName] stringByDeletingLastPathComponent];
        nameString = [[nameString stringByAppendingString:@"/"] 
        stringByAppendingString: [NSString stringWithContentsOfFile: projectPath]];
        nameString = [nameString stringByStandardizingPath];
        }
        
    // is the document open?
    wlist=[NSApp orderedDocuments];
    en=[wlist objectEnumerator];
    while(obj=[en nextObject]) {
        if([[obj windowNibName] isEqualToString:@"MyDocument"]) {
            if([[obj fileName] isEqualToString:nameString]) {
                if (obj == self)
                    return NO;
                if (task == RootForPrinting) {
                    [obj printDocument:nil];
                    }
                else if (task == RootForTexing)
                    {rootDocument = obj;
                    switch(whichEngine) {
                        case TexEngine: [obj doTex:nil]; break;
                        case LatexEngine: [obj doLatex:nil]; break;
                        case ContextEngine: [obj doContext:nil]; break;
                        case MetapostEngine: [obj doMetapost:nil]; break;
                        case BibtexEngine: [obj doBibtex:nil]; break;
                        case IndexEngine: [obj doIndex:nil]; break;
                        case MetafontEngine: [obj doMetaFont:nil]; break;
                        default: NSBeginAlertSheet(@"Typesetting engine cannot be found.",
                            nil,nil,nil,[textView window],nil,nil,nil,nil,
                            @"Path Name: %@",nameString);
                        }
                    }
                else if (task == RootForOpening) {
                    ;
                    }
                return YES;
                }
        }
    }
        
    // document not found, open document and typeset
    dc=[NSDocumentController sharedDocumentController];
    obj=[dc openDocumentWithContentsOfFile:nameString display:YES];
    if(obj) {
        if (obj == self)
            return NO;
        if (task == RootForPrinting) {
            [obj printDocument:nil];
            }
        else if (task == RootForTexing)
            {rootDocument = obj;
             switch(whichEngine) {
                case TexEngine: [obj doTex:nil]; break;
                case LatexEngine: [obj doLatex:nil]; break;
                case ContextEngine: [obj doContext:nil]; break;
                case MetapostEngine: [obj doMetapost:nil]; break;
                case BibtexEngine: [obj doBibtex:nil]; break;
                case IndexEngine: [obj doIndex:nil]; break;
                case MetafontEngine: [obj doMetaFont:nil]; break;
                default: NSBeginAlertSheet(@"Typesetting engine cannot be found.",
                    nil,nil,nil,[textView window],nil,nil,nil,nil,
                    @"Path Name: %@",nameString);
                }
            }
        else if (task == RootForOpening) {
            [[obj textWindow] miniaturize:self];
            }
        return YES;
        }
    else
        {	NSBeginAlertSheet(@"The source LaTeX document can not be found.",
                nil,nil,nil,[textView window],nil,nil,nil,nil,
                @"Path Name: %@",nameString);
        }
    return YES;
}


- (void) checkFileLinks:(NSString *)theSource
{ 
    NSString *home,*jobname=[[self fileName] stringByDeletingLastPathComponent];
    NSRange aRange,bRange;
    NSString *saveName, *searchString;
    NSMutableArray *slist;
    NSArray *wlist;
    NSEnumerator *en;
    id obj;
    unsigned numFiles,i;

    if (![SUD boolForKey:SaveRelatedKey])
        return;
    
    // load home path and jobname
    home=[[self fileName] stringByDeletingLastPathComponent];
    jobname=[[[self fileName] lastPathComponent] stringByDeletingPathExtension];

    // create list of linked files from \input commands
    aRange=NSMakeRange(0,[theSource length]);
    slist=[[NSMutableArray alloc] init];
    searchString = [NSString stringWithString:@"\\input"];
    if (shouldFilter == filterMacJ)
                searchString = filterBackslashToYen(searchString);
    while(YES)
    {	aRange=[theSource rangeOfString:searchString options:NSLiteralSearch range:aRange];
        if(aRange.location==NSNotFound) break;
        bRange=[theSource lineRangeForRange:aRange];
        saveName=[self readInputArg:[theSource substringWithRange:bRange]
                        atIndex:aRange.location-bRange.location+6
                        homePath:home job:jobname];
        saveName = [saveName stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        if(saveName) 
            [slist addObject:saveName];
        aRange.location+=6;
        aRange.length=[theSource length]-aRange.location;
    }
    numFiles=[slist count];
    
    if(numFiles==0)
    {	
        [slist release];
        return;
    }
    
    // compare file list to current MyDocuments
    wlist=[NSApp orderedDocuments];
    en=[wlist objectEnumerator];
    
    while(obj=[en nextObject])
    {	if([[obj windowNibName] isEqualToString:@"MyDocument"])
        {   saveName=[obj fileName];
            for(i=0;i<numFiles;i++)
            {   
            if([saveName isEqualToString:[slist objectAtIndex:i]])
                {  if([obj isDocumentEdited]) 
                       [obj saveDocument:self];
                    break;
                }
            }
        }
    }
    
    // release file list
    [slist release];
}

// added by John A. Nairn
// read argument to \input command and resolve to full path name
// ignore \input commands that have been commented out
- (NSString *) readInputArg:(NSString *)fileLine atIndex:(unsigned)i
        homePath:(NSString *)home job:(NSString *)jobname
{
    unichar firstChar;
    NSRange aRange;
    
    // error if no command argument data
    if(i>=[fileLine length]) return nil;
    
    // skip if commented out
    aRange=[fileLine rangeOfString:@"%" options:NSLiteralSearch];
    if(aRange.location!=NSNotFound && aRange.location<i)
    {	// exit unless % is escaped with back slash
    	if(aRange.location==0) return nil;
        firstChar=[fileLine characterAtIndex:aRange.location-1];
        if(firstChar!='\\') return nil;
    }
    
    // check if next character is { or ' '
    firstChar=[fileLine characterAtIndex:i];
    
    // argument in {}'s
    if(firstChar=='{')
    {	// find ending brace
        aRange=[fileLine rangeOfString:@"}" options:NSLiteralSearch
                    range:NSMakeRange(i,[fileLine length]-i)];
        if(aRange.location==NSNotFound) return nil;
        return [self decodeFile:[fileLine substringWithRange:NSMakeRange(i+1,aRange.location-1-i)]
                    homePath:home job:jobname];
    }
    
    // argument after space(s)
    else if(firstChar==' ')
    {	// skip any number of spaces
        while(firstChar==' ')
        {   i++;
            if(i>=[fileLine length]) return nil;
            firstChar=[fileLine characterAtIndex:i];
        }
        
        // find next space or line end
        aRange=[fileLine rangeOfString:@" " options:NSLiteralSearch
                    range:NSMakeRange(i,[fileLine length]-i)];
        if(aRange.location==NSNotFound) 
            aRange=NSMakeRange(i,[fileLine length]-i);
        else
            aRange=NSMakeRange(i,aRange.location-i);
            
        return [self decodeFile:[fileLine substringWithRange:aRange]
                    homePath:home job:jobname];
    }
    
    // not an input command
    else
        return nil;
}

// added by John A. Nairn
// get full path name for possible relative file name in relFile
// relative is from home
- (NSString *) decodeFile:(NSString *)relFile homePath:(NSString *)home job:(NSString *)jobname
{
    NSString *saveName, *searchString;
    NSMutableString *saveTemp;
    unichar firstChar;
    NSRange aRange;
    
    // trim white space first
    relFile=[relFile stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    
    // expand to full path
    firstChar=[relFile characterAtIndex:0];
    if(firstChar=='~')
        saveName=[relFile stringByExpandingTildeInPath];
    else if(firstChar=='/')
        saveName=relFile;
    else if(firstChar=='.')
    {	while([relFile length]>=3)
        {   if(![[relFile substringToIndex:3] isEqualToString:@"../"]) break;
            home=[home stringByDeletingLastPathComponent];
            relFile=[relFile substringFromIndex:3];
        }
        saveName=[NSString stringWithFormat:@"%@/%@",home,relFile];
    }
    else
        saveName=[NSString stringWithFormat:@"%@/%@",home,relFile];
    
    // see if \jobname is there
    searchString = [NSString stringWithString:@"\\jobname"];
    if (shouldFilter == filterMacJ)
        searchString = filterBackslashToYen(searchString);
    aRange=[saveName rangeOfString:searchString options:NSLiteralSearch];
    if(aRange.location==NSNotFound) return saveName;
    
    // replace \jobname(s)
    saveTemp=[NSMutableString stringWithString:saveName];
    [saveTemp replaceOccurrencesOfString:searchString withString:jobname options:NSLiteralSearch
                    range:NSMakeRange(0,[saveName length])];
    return [NSString stringWithString:saveTemp];
}

// mitsu 1.29 (Q)
- (void)showInfo: (id)sender
{
	NSString *filePath, *fileInfo, *infoTitle, *infoText;
	NSDictionary *fileAttrs;
	NSNumber *fsize;
	NSDate *creationDate, *modificationDate;

	filePath = [self fileName];
	if (filePath && 
		(fileAttrs = [[NSFileManager defaultManager] fileAttributesAtPath:filePath traverseLink:YES]))
	{
		fsize = [fileAttrs objectForKey:NSFileSize];
		creationDate = [fileAttrs objectForKey:NSFileCreationDate];
		modificationDate = [fileAttrs objectForKey:NSFileModificationDate];
		fileInfo = [NSString stringWithFormat: 
					NSLocalizedString(@"Path: %@\nFile size: %d bytes\nCreation date: %@\nModification date: %@", @"File Info"), 
		filePath, 
		fsize?[fsize intValue]:0, 
		creationDate?[creationDate description]:@"", 
		modificationDate?[modificationDate description]:@""];
	}
	else
		fileInfo = @"Not saved";

	infoTitle = [NSString stringWithFormat: 
					NSLocalizedString(@"Info: %@", @"Info: %@"),
					[self displayName]];
	infoText = [NSString stringWithFormat: 
					NSLocalizedString(@"%@\n\nCharacters: %d", @"InfoText"),
					fileInfo, 
					[[textView string] length]];
	NSRunAlertPanel(infoTitle, infoText, nil, nil, nil);
}
// end mitsu 1.29

// mitsu 1.29 (T4)
- (BOOL)isDoAutoCompleteEnabled
{
	return doAutoComplete;
}

// end mitsu 1.29

// mitsu 1.29 (P) if CommandCompletion List is being saved, reload it.  
- (void)saveDocument: (id)sender
{
	[super saveDocument: sender];
	// reload CommandCompletion List
	if (!fileIsTex && [[self fileName] isEqualToString: 
				[CommandCompletionPathKey stringByStandardizingPath]])
		[[NSApp delegate] finishCommandCompletionConfigure];
}

// end mitsu 1.29


// mitsu 1.29 (T)
// to be used in LaTeX Panel/Macro/...
- (void)insertSpecial:(NSString *)theString undoKey:(NSString *)key
{
	NSRange		oldRange, searchRange;
    NSMutableString	*newString;
	NSString *oldString;

	// mutably copy the replacement text
	newString = [NSMutableString stringWithString: theString];

	// Determine the curent selection range and text
	oldRange = [textView selectedRange];
	oldString = [[textView string] substringWithRange: oldRange];

	// Substitute all occurances of #SEL# with the original text
	[newString replaceOccurrencesOfString: @"#SEL#" withString: oldString
					options: 0 range: NSMakeRange(0, [newString length])];

	// Now search for #INS#, remember its position, and remove it. We will
	// Later position the insertion mark there. Defaults to end of string.
	searchRange = [newString rangeOfString:@"#INS#" options:NSLiteralSearch];
	if (searchRange.location != NSNotFound)
		[newString replaceCharactersInRange:searchRange withString:@""];

	// Filtering for Japanese
	if (shouldFilter == filterMacJ)
		newString = filterBackslashToYen(newString);

	// Replace the text--
		// Follow Apple's guideline "Subclassing NSTextView/Notifying About Changes to the Text" 
		// in "Text System User Interface Layer". 
		// This means bracketing each batch of potential changes with 
		// "shouldChangeTextInRange:replacementString:" and "didChangeText" messages
	if ([textView shouldChangeTextInRange:oldRange replacementString:newString]) 
	{
		[textView replaceCharactersInRange:oldRange withString:newString];
		[textView didChangeText];
		
		if (key)
			[[textView undoManager] setActionName: key];
		
		// Place insertion mark
		if (searchRange.location != NSNotFound)
		{
			searchRange.location += oldRange.location;
			searchRange.length = 0;
			[textView setSelectedRange:searchRange];
		}
	}
}


// to be used in AutoCompletion
- (void)insertSpecialNonStandard:(NSString *)theString undoKey:(NSString *)key
{
	NSRange		oldRange, searchRange;
    NSMutableString	*newString;
	NSString *oldString;
	unsigned from, to;

	// mutably copy the replacement text
	newString = [NSMutableString stringWithString: theString];

	// Determine the curent selection range and text
	oldRange = [textView selectedRange];
	oldString = [[textView string] substringWithRange: oldRange];

	// Substitute all occurances of #SEL# with the original text
	[newString replaceOccurrencesOfString: @"#SEL#" withString: oldString
					options: 0 range: NSMakeRange(0, [newString length])];

	// Now search for #INS#, remember its position, and remove it. We will
	// Later position the insertion mark there. Defaults to end of string.
	searchRange = [newString rangeOfString:@"#INS#" options:NSLiteralSearch];
	if (searchRange.location != NSNotFound)
		[newString replaceCharactersInRange:searchRange withString:@""];

	// Filtering for Japanese
	if (shouldFilter == filterMacJ)
		newString = filterBackslashToYen(newString);

	// Insert the new text
	[textView replaceCharactersInRange:oldRange withString:newString];
	
	// register undo
	[self registerUndoWithString:oldString location:oldRange.location 
						length:[newString length] key:key];
	//[textView registerUndoWithString:oldString location:oldRange.location 
	//					length:[newString length] key:key];
	
	from = oldRange.location;
	to = from + [newString length];
	[self fixColor:from :to];
	[self setupTags];

	// Place insertion mark
	if (searchRange.location != NSNotFound)
	{
		searchRange.location += oldRange.location;
		searchRange.length = 0;
		[textView setSelectedRange:searchRange];
	}
}


- (void)registerUndoWithString:(NSString *)oldString location:(unsigned)oldLocation 
	length: (unsigned)newLength key:(NSString *)key
{
    NSUndoManager	*myManager;
    NSMutableDictionary	*myDictionary;
    NSNumber		*theLocation, *theLength;

	// Create & register an undo action
	myManager = [textView undoManager];
	myDictionary = [NSMutableDictionary dictionaryWithCapacity: 4];
	theLocation = [NSNumber numberWithUnsignedInt: oldLocation];
	theLength = [NSNumber numberWithUnsignedInt: newLength];
	[myDictionary setObject: oldString forKey: @"oldString"];
	[myDictionary setObject: theLocation forKey: @"oldLocation"];
	[myDictionary setObject: theLength forKey: @"oldLength"];
	[myDictionary setObject: key forKey: @"undoKey"];
	[myManager registerUndoWithTarget:self selector:@selector(undoSpecial:) object: myDictionary];
	[myManager setActionName:key];
}

- (void)undoSpecial:(id)theDictionary
{
    NSRange		undoRange;
    NSString	*oldString, *newString, *undoKey;
	unsigned	from, to;

    // Retrieve undo info
    undoRange.location = [[theDictionary objectForKey: @"oldLocation"] unsignedIntValue];
    undoRange.length = [[theDictionary objectForKey: @"oldLength"] unsignedIntValue];
    newString = [theDictionary objectForKey: @"oldString"];
    undoKey = [theDictionary objectForKey: @"undoKey"];
	
	if (undoRange.location+undoRange.length > [[textView string] length])
		return; // something wrong happened
		
	oldString = [[textView string] substringWithRange: undoRange];

	// Replace the text
	[textView replaceCharactersInRange:undoRange withString:newString];
	[self registerUndoWithString:oldString location:undoRange.location 
						length:[newString length] key:undoKey];
	
	from = undoRange.location;
	to = from + [newString length];
	[self fixColor:from :to];
	[self setupTags];
}

// end mitsu 1.29

// mitsu 1.29 (T3)
- (void) doCommentOrIndent: (id)sender
{
    NSString		*text, *oldString;
    NSRange		myRange, modifyRange, tempRange, oldRange;
    unsigned		start, end, end1, changeStart, changeEnd;
    int			theChar;
    //NSUndoManager	*myManager;
    //NSMutableDictionary	*myDictionary;
    //NSNumber		*theLocation, *theLength, *theType;

    text = [textView string];
    myRange = [textView selectedRange];
    // get old string for Undo
    [text getLineStart:&start end:&end contentsEnd:&end1 forRange:myRange];
    oldRange.location = start;
    oldRange.length = end1 - start;
    oldString = [[textView string] substringWithRange: oldRange];

    changeStart = start;
    changeEnd = start;
    end = start;
    while (end < (myRange.location + myRange.length)) {
        modifyRange.location = end;
        modifyRange.length = 0;
        [text getLineStart:&start end:&end contentsEnd:&end1 forRange:modifyRange];
        changeEnd = end1;
        if ((end1 - start) > 0)
            theChar = [text characterAtIndex: start];
        switch ([sender tag]) {
        
            case Mcomment:	// if ((end1 == start)  || (theChar != 0x0025) ) {
                                    tempRange.location = start;
                                    tempRange.length = 0;
                                    [textView replaceCharactersInRange:tempRange withString:@"%"];
                                    myRange.length++; oldRange.length++;
                                    changeEnd++;
                                    end++;
                                //    }
                                break;
                                            
            case Muncomment:	if ((end1 != start) && (theChar == 0x0025)) {
                                    tempRange.location = start;
                                    tempRange.length = 1;
                                    [textView replaceCharactersInRange:tempRange withString:@""];
                                    myRange.length--; oldRange.length--;
                                    changeEnd--;
                                    end--;
                                    }
                                break;
            
            // Originally this was a space; Greg Landweber correctly suggested a tab!
            case Mindent: 	if (0 == 0) // (end1 == start) || (theChar != 0x0025))  
							{
                                    tempRange.location = start;
                                    tempRange.length = 0;
                                    [textView replaceCharactersInRange:tempRange withString:@"\t"];
                                    myRange.length++; oldRange.length++;
                                    changeEnd++;
                                    end++;
                                    }
                                break;

            
            case Munindent: 	if ((end1 != start) && (theChar == '\t')) {
                                    tempRange.location = start;
                                    tempRange.length = 1;
                                    [textView replaceCharactersInRange:tempRange withString:@""];
                                    myRange.length--; oldRange.length--;
                                    changeEnd--;
                                    end--;
                                    }
                                break;

            }
        end++;
        }
    [self fixColor:changeStart :changeEnd];
    tempRange.location = changeStart;
    tempRange.length = (changeEnd - changeStart);
    [textView setSelectedRange: tempRange];

	[self registerUndoWithString:oldString location:oldRange.location 
						length:oldRange.length key: [sender title]];
}

// end mitsu 1.29

- (void)newTag: (id)sender;
{
    NSString		*text;
    NSRange		myRange, tempRange;
    unsigned		start, end, end1, changeStart, changeEnd;
    int			theChar;

    text = [textView string];
    myRange = [textView selectedRange];
    // get old string for Undo
    [text getLineStart:&start end:&end contentsEnd:&end1 forRange:myRange];
    tempRange.location = start;
    tempRange.length = 0;
    [textView replaceCharactersInRange:tempRange withString:@"%:\n"];
    changeStart = tempRange.location;
    changeEnd = changeStart + 2;
    [self fixColor:changeStart :changeEnd];
    [self registerUndoWithString:@"" location:tempRange.location 
						length:3 key: @"New Tag"];
    tempRange.location = start+2;
    tempRange.length = 0;
    [textView setSelectedRange: tempRange];
}

@end

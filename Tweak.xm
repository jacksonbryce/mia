#import "Interfaces.h"
#import "BDSettingsManager.h"

static BOOL newCompCheck = NO;
static float delayValue = 0.0;

%hook SMSApplication

- (void)systemApplicationDidSuspend {
	dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (delayValue + 3.1) * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
		CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(), CFSTR("com.brycedev.mia.center.appsuspend"), nil, nil, YES);
	});
    %orig;
}

%end

%hook CKTranscriptController

- (void)viewDidLoad {
	%orig;
    [[NSNotificationCenter defaultCenter] addObserver:self
                                          selector:@selector(studyTextExistence)
                                          name:UIApplicationWillResignActiveNotification object:nil];
}

- (void)messageEntryViewDidBeginEditing:(CKMessageEntryView *)view {
    CKConversation *convo = [self conversation];
    IMChat *chat = [convo chat];
    NSMutableDictionary *notesDict = [[BDSettingsManager sharedManager] notifications];
    if (!([notesDict count] == 0)) {
        if ([notesDict objectForKey:chat.chatIdentifier]) {
            [notesDict removeObjectForKey:chat.chatIdentifier];
            [[BDSettingsManager sharedManager] setNotifications: notesDict];
        }
    }
    %orig;
}

- (void)viewDidDisappear:(BOOL)animated {
	%orig;
    [self studyTextExistence];
}

- (void)viewWillAppear:(BOOL)animated {
	%orig;
	if([self.navigationItem.title isEqualToString: @"New Message"])
		newCompCheck = YES;
	else
		newCompCheck = NO;
    [self studyTextExistence];
}

- (void)sendMessage:(CKComposition*)message {
	%orig;
	CKConversation *convo = [self conversation];
	IMChat *chat = [convo chat];
    NSMutableDictionary *notesDict = [[BDSettingsManager sharedManager] notifications];
    if (!([notesDict count] == 0)) {
        if ([notesDict objectForKey:chat.chatIdentifier]) {
            [notesDict removeObjectForKey:chat.chatIdentifier];
            [[BDSettingsManager sharedManager] setNotifications: notesDict];
        }
    }
}

%new
- (void)studyTextExistence {
	if(!newCompCheck){
		CKComposition *comp = [self composition];
	    CKConversation *convo = [self conversation];
	    IMChat *chat = [convo chat];
	    if([comp hasNonwhiteSpaceContent]){
	        NSArray *convoInfo = @[convo.name, chat.chatIdentifier];
	        [self addNewNotification: convoInfo];
	    }else {
	        NSMutableDictionary *notesDict = [[BDSettingsManager sharedManager] notifications];
	        if (!([notesDict count] == 0)) {
	            if ([notesDict objectForKey: chat.chatIdentifier]) {
	                [notesDict removeObjectForKey: chat.chatIdentifier];
	                [[BDSettingsManager sharedManager] setNotifications: notesDict];
	            }
	        }
	    }
	}
}

%new
- (void)addNewNotification:(NSArray*)array {
    NSMutableDictionary *notesDict = [[BDSettingsManager sharedManager] notifications];
    [notesDict setObject: [array objectAtIndex:0] forKey: [array objectAtIndex:1]];
    [[BDSettingsManager sharedManager] setNotifications: notesDict];
}

%end

%hook CKConversationList

- (void)deleteConversation:(CKConversation *)conversation {
    IMChat *chat = [conversation chat];
    NSMutableDictionary *notesDict = [[BDSettingsManager sharedManager] notifications];
    if (!([notesDict count] == 0)) {
        if ([notesDict objectForKey: chat.chatIdentifier]) {
            [notesDict removeObjectForKey: chat.chatIdentifier];
            [[BDSettingsManager sharedManager] setNotifications: notesDict];
         }
    }
    %orig;
}

- (void)deleteConversations:(NSArray*)array {
    NSMutableDictionary *notesDict = [[BDSettingsManager sharedManager] notifications];
    for (CKConversation * convo in array){
        if (!([notesDict count] == 0)) {
			IMChat *chat = [convo chat];
            if ([notesDict objectForKey: chat.chatIdentifier]) {
                [notesDict removeObjectForKey: chat.chatIdentifier];
                [[BDSettingsManager sharedManager] setNotifications: notesDict];
            }
        }
    }
    %orig;
}

%end

%hook SBBannerContainerViewController

-(void)_handleBannerTapGesture:(id)gesture withActionContext:(id)context {
	if([[[UIDevice currentDevice] systemVersion] floatValue] >= 9.0){
		if( [[[self _bulletin] sectionID] containsString:@"com.brycedev.mia"] ){
			if([[[self _bulletin] sectionID] isEqualToString:@"com.brycedev.mia"]){
				[[UIApplication sharedApplication] launchApplicationWithIdentifier:@"com.apple.MobileSMS" suspended:NO];
			}else{
				NSString *identifier = [[[self _bulletin] sectionID] stringByReplacingOccurrencesOfString:@"com.brycedev.mia" withString:@""];
				[[UIApplication sharedApplication] openURL:[NSURL URLWithString:[@"sms://" stringByAppendingString:identifier]]];
			}
			return;
		}else{
			%orig;
		}
	}
	else{
		%orig;
	}
}

%end

static void cookNotifications(){
	[[BDSettingsManager sharedManager] updateSettings];
	NSMutableDictionary *notesDict = [[BDSettingsManager sharedManager] notifications];
	//HBLogInfo(@"getting the notifications : %@", notesDict);
    if ( (!([notesDict count] == 0)) && [[BDSettingsManager sharedManager] enabled]) {
		//HBLogInfo(@"cooking notifications");
        id request = [[[%c(BBBulletinRequest) alloc] init] autorelease];
        [request setTitle: @"MiaAssistant"];
        if([notesDict count] == 1){
            [request setMessage:[NSString stringWithFormat:@"You forgot to send your message to %@", [notesDict objectForKey: [[notesDict allKeys] objectAtIndex:0]]]];
            [request setDefaultAction: [%c(BBAction) actionWithLaunchURL: [NSURL URLWithString: [NSString stringWithFormat:@"sms:%@", [[notesDict allKeys] objectAtIndex:0]]]]];
        }else if([notesDict count] == 2){
            NSString * people = [[notesDict allValues] componentsJoinedByString:@" and "];
            [request setMessage:[NSString stringWithFormat:@"You forgot to send your messages to : %@", people]];
            [request setDefaultAction: [%c(BBAction) actionWithLaunchBundleID:@"com.apple.MobileSMS"]];
        }else {
            NSString * people = [[notesDict allValues] componentsJoinedByString:@", "];
            [request setMessage:[NSString stringWithFormat:@"You forgot to send your messages to : %@", people]];
            [request setDefaultAction: [%c(BBAction) actionWithLaunchBundleID:@"com.apple.MobileSMS"]];
        }
		if([[[UIDevice currentDevice] systemVersion] floatValue] >= 9.0){
			if([notesDict count] == 1){
				[request setSectionID: [NSString stringWithFormat:@"com.brycedev.mia%@", [[notesDict allKeys] objectAtIndex:0]]];
			}else{
				[request setSectionID: @"com.brycedev.mia"];
			}
		}else{
			[request setSectionID: @"com.apple.MobileSMS"];
		}
        id ctrl = [%c(SBBulletinBannerController) sharedInstance];
        if([ctrl respondsToSelector:@selector(observer:addBulletin:forFeed:playLightsAndSirens:withReply:)]) {
            [ctrl observer:nil addBulletin:request forFeed:2 playLightsAndSirens:YES withReply:nil];
        } else {
            [ctrl observer:nil addBulletin:request forFeed:2];
        }
    }
}


static void testBanner(){
    id request = [[[%c(BBBulletinRequest) alloc] init] autorelease];
    [request setTitle: @"MiaAssistant"];
    NSArray *testNames = [@[ @"Tim Cook", @"Jay Freeman", @"Morgan Freeman", @"Steve Carell", @"Oliver Queen", @"Oprah Winfrey" ] retain];
    [request setMessage:[NSString stringWithFormat: @"You forgot to send your message to %@", [testNames objectAtIndex: arc4random() % [testNames count]]]];
    [request setDefaultAction: [%c(BBAction) actionWithLaunchBundleID: @"com.apple.MobileSMS"]];
	if([[[UIDevice currentDevice] systemVersion] floatValue] >= 9.0){
		[request setSectionID: @"com.brycedev.mia"];
	}else{
		[request setSectionID: @"com.apple.MobileSMS"];
	}
    id ctrl = [%c(SBBulletinBannerController) sharedInstance];
    if([ctrl respondsToSelector:@selector(observer:addBulletin:forFeed:playLightsAndSirens:withReply:)]) {
        [ctrl observer:nil addBulletin:request forFeed:2 playLightsAndSirens:YES withReply:nil];
    } else {
        [ctrl observer:nil addBulletin:request forFeed:2];
    }
}

%ctor{
	dlopen("/Library/MobileSubstrate/DynamicLibraries/SendDelay.dylib", RTLD_NOW);
	CFStringRef sdApp = CFSTR("com.gsquared.senddelay");
    CFArrayRef keyList = CFPreferencesCopyKeyList(sdApp , kCFPreferencesCurrentUser, kCFPreferencesAnyHost) ?: CFArrayCreate(NULL, NULL, 0, NULL);
    NSDictionary *sdDict = (NSDictionary *)CFPreferencesCopyMultiple(keyList, sdApp , kCFPreferencesCurrentUser, kCFPreferencesAnyHost);
    CFRelease(keyList);
	if(sdDict != nil)
		delayValue = [sdDict[@"delayValue"] doubleValue];

	[BDSettingsManager sharedManager];
    CFNotificationCenterRef r = CFNotificationCenterGetDarwinNotifyCenter();
    CFNotificationCenterAddObserver(r, NULL, (CFNotificationCallback)cookNotifications, CFSTR("com.brycedev.mia.center.appsuspend"), NULL, 0);
    CFNotificationCenterAddObserver(r, NULL, (CFNotificationCallback)testBanner, CFSTR("com.brycedev.mia.testbanner"), NULL, 0);

}

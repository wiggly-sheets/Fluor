//
//  PFMoveApplication.m, version 1.24
//  LetsMove
//
//  Created by Andy Kim at Potion Factory LLC on 9/17/09
//
//  The contents of this file are dedicated to the public domain.

#import "PFMoveApplication.h"

#import <AppKit/AppKit.h>
#import <Security/Security.h>
#import <dlfcn.h>
#import <sys/mount.h>

@interface LetsMove : NSObject
@end

@implementation LetsMove
+ (NSBundle *)bundle {
	return [NSBundle bundleForClass:self];
}
@end

#define _I10NS(nsstr) NSLocalizedStringFromTableInBundle(nsstr, @"MoveApplication", [LetsMove bundle], nil)
#define kStrMoveApplicationCouldNotMove _I10NS(@"Could not move to Applications folder")
#define kStrMoveApplicationQuestionTitle  _I10NS(@"Move to Applications folder?")
#define kStrMoveApplicationQuestionTitleHome _I10NS(@"Move to Applications folder in your Home folder?")
#define kStrMoveApplicationQuestionMessage _I10NS(@"I can move myself to the Applications folder if you'd like.")
#define kStrMoveApplicationButtonMove _I10NS(@"Move to Applications Folder")
#define kStrMoveApplicationButtonDoNotMove _I10NS(@"Do Not Move")
#define kStrMoveApplicationQuestionInfoWillRequirePasswd _I10NS(@"Note that this will require an administrator password.")
#define kStrMoveApplicationQuestionInfoInDownloadsFolder _I10NS(@"This will keep your Downloads folder uncluttered.")

#ifndef NSAppKitVersionNumber10_5
	#define NSAppKitVersionNumber10_5 949
#endif

#define PFUseSmallAlertSuppressCheckbox 1


static NSString *AlertSuppressKey = @"moveToApplicationsFolderAlertSuppress";
static BOOL MoveInProgress = NO;

static NSString *PreferredInstallLocation(BOOL *isUserDirectory);
static BOOL IsInApplicationsFolder(NSString *path);
static BOOL IsInDownloadsFolder(NSString *path);
static BOOL IsApplicationAtPathRunning(NSString *path);
static BOOL IsApplicationAtPathNested(NSString *path);
static NSString *ContainingDiskImageDevice(NSString *path);
static BOOL Trash(NSString *path);
static BOOL DeleteOrTrash(NSString *path);
static BOOL AuthorizedInstall(NSString *srcPath, NSString *dstPath, BOOL *canceled);
static BOOL CopyBundle(NSString *srcPath, NSString *dstPath);
static NSString *ShellQuotedString(NSString *string);
static void Relaunch(NSString *destinationPath);

void PFMoveToApplicationsFolderIfNecessary(void) {

	if (![NSThread isMainThread]) {
		dispatch_async(dispatch_get_main_queue(), ^{
			PFMoveToApplicationsFolderIfNecessary();
		});
		return;
	}
	
	if ([[NSUserDefaults standardUserDefaults] boolForKey:AlertSuppressKey]) return;

	NSString *bundlePath = [[NSBundle mainBundle] bundlePath];

	BOOL isNestedApplication = IsApplicationAtPathNested(bundlePath);

	if (IsInApplicationsFolder(bundlePath) && !isNestedApplication) return;

	MoveInProgress = YES;
	
	NSFileManager *fm = [NSFileManager defaultManager];

	NSString *diskImageDevice = ContainingDiskImageDevice(bundlePath);

	BOOL installToUserApplications = NO;
	NSString *applicationsDirectory = PreferredInstallLocation(&installToUserApplications);
	NSString *bundleName = [bundlePath lastPathComponent];
	NSString *destinationPath = [applicationsDirectory stringByAppendingPathComponent:bundleName];

	BOOL needAuthorization = ([fm isWritableFileAtPath:applicationsDirectory] == NO);

	needAuthorization |= ([fm fileExistsAtPath:destinationPath] && ![fm isWritableFileAtPath:destinationPath]);

	NSAlert *alert = [[[NSAlert alloc] init] autorelease];
	{
		NSString *informativeText = nil;

		[alert setMessageText:(installToUserApplications ? kStrMoveApplicationQuestionTitleHome : kStrMoveApplicationQuestionTitle)];

		informativeText = kStrMoveApplicationQuestionMessage;

		if (needAuthorization) {
			informativeText = [informativeText stringByAppendingString:@" "];
			informativeText = [informativeText stringByAppendingString:kStrMoveApplicationQuestionInfoWillRequirePasswd];
		}
		else if (IsInDownloadsFolder(bundlePath)) {
			informativeText = [informativeText stringByAppendingString:@" "];
			informativeText = [informativeText stringByAppendingString:kStrMoveApplicationQuestionInfoInDownloadsFolder];
		}

		[alert setInformativeText:informativeText];

		[alert addButtonWithTitle:kStrMoveApplicationButtonMove];

		NSButton *cancelButton = [alert addButtonWithTitle:kStrMoveApplicationButtonDoNotMove];
		[cancelButton setKeyEquivalent:[NSString stringWithFormat:@"%C", 0x1b]]; // Escape key

		[alert setShowsSuppressionButton:YES];

		if (PFUseSmallAlertSuppressCheckbox) {
			NSCell *cell = [[alert suppressionButton] cell];
			[cell setControlSize: NSControlSizeSmall];
			[cell setFont:[NSFont systemFontOfSize:[NSFont smallSystemFontSize]]];
		}
	}

	if (![NSApp isActive]) {
		[NSApp activateIgnoringOtherApps:YES];
	}

	if ([alert runModal] == NSAlertFirstButtonReturn) {
		NSLog(@"INFO -- Moving myself to the Applications folder");

		if (needAuthorization) {
			BOOL authorizationCanceled;

			if (!AuthorizedInstall(bundlePath, destinationPath, &authorizationCanceled)) {
				if (authorizationCanceled) {
					NSLog(@"INFO -- Not moving because user canceled authorization");
					MoveInProgress = NO;
					return;
				}
				else {
					NSLog(@"ERROR -- Could not copy myself to /Applications with authorization");
					goto fail;
				}
			}
		}
		else {
			if ([fm fileExistsAtPath:destinationPath]) {
				if (IsApplicationAtPathRunning(destinationPath)) {
					NSLog(@"INFO -- Switching to an already running version");
					[[NSTask launchedTaskWithLaunchPath:@"/usr/bin/open" arguments:[NSArray arrayWithObject:destinationPath]] waitUntilExit];
					MoveInProgress = NO;
					exit(0);
				}
				else {
					if (!Trash([applicationsDirectory stringByAppendingPathComponent:bundleName]))
						goto fail;
				}
			}

 			if (!CopyBundle(bundlePath, destinationPath)) {
				NSLog(@"ERROR -- Could not copy myself to %@", destinationPath);
				goto fail;
			}
		}

		if (!isNestedApplication && diskImageDevice == nil && !DeleteOrTrash(bundlePath)) {
			NSLog(@"WARNING -- Could not delete application after moving it to Applications folder");
		}

		Relaunch(destinationPath);

		if (diskImageDevice && !isNestedApplication) {
			NSString *script = [NSString stringWithFormat:@"(/bin/sleep 5 && /usr/bin/hdiutil detach %@) &", ShellQuotedString(diskImageDevice)];
			[NSTask launchedTaskWithLaunchPath:@"/bin/sh" arguments:[NSArray arrayWithObjects:@"-c", script, nil]];
		}

		MoveInProgress = NO;
		exit(0);
	}
	else if ([[alert suppressionButton] state] == NSOnState) {
		[[NSUserDefaults standardUserDefaults] setBool:YES forKey:AlertSuppressKey];
	}

	MoveInProgress = NO;
	return;

fail:
	{
		alert = [[[NSAlert alloc] init] autorelease];
		[alert setMessageText:kStrMoveApplicationCouldNotMove];
		[alert runModal];
		MoveInProgress = NO;
	}
}

BOOL PFMoveIsInProgress() {
    return MoveInProgress;
}

#pragma mark -
#pragma mark Helper Functions

static NSString *PreferredInstallLocation(BOOL *isUserDirectory) {

	NSFileManager *fm = [NSFileManager defaultManager];

	NSArray *userApplicationsDirs = NSSearchPathForDirectoriesInDomains(NSApplicationDirectory, NSUserDomainMask, YES);

	if ([userApplicationsDirs count] > 0) {
		NSString *userApplicationsDir = [userApplicationsDirs objectAtIndex:0];
		BOOL isDirectory;

		if ([fm fileExistsAtPath:userApplicationsDir isDirectory:&isDirectory] && isDirectory) {
			NSArray *contents = [fm contentsOfDirectoryAtPath:userApplicationsDir error:NULL];

			for (NSString *contentsPath in contents) {
				if ([[contentsPath pathExtension] isEqualToString:@"app"]) {
					if (isUserDirectory) *isUserDirectory = YES;
					return [userApplicationsDir stringByResolvingSymlinksInPath];
				}
			}
		}
	}

	if (isUserDirectory) *isUserDirectory = NO;

	return [[NSSearchPathForDirectoriesInDomains(NSApplicationDirectory, NSLocalDomainMask, YES) lastObject] stringByResolvingSymlinksInPath];
}

static BOOL IsInApplicationsFolder(NSString *path) {
	NSArray *applicationDirs = NSSearchPathForDirectoriesInDomains(NSApplicationDirectory, NSAllDomainsMask, YES);
	for (NSString *appDir in applicationDirs) {
		if ([path hasPrefix:appDir]) return YES;
	}

	if ([[path pathComponents] containsObject:@"Applications"]) return YES;

	return NO;
}

static BOOL IsInDownloadsFolder(NSString *path) {
	NSArray *downloadDirs = NSSearchPathForDirectoriesInDomains(NSDownloadsDirectory, NSAllDomainsMask, YES);
	for (NSString *downloadsDirPath in downloadDirs) {
		if ([path hasPrefix:downloadsDirPath]) return YES;
	}

	return NO;
}

static BOOL IsApplicationAtPathRunning(NSString *bundlePath) {
	bundlePath = [bundlePath stringByStandardizingPath];

#if MAC_OS_X_VERSION_MAX_ALLOWED > MAC_OS_X_VERSION_10_5
	if (floor(NSAppKitVersionNumber) > NSAppKitVersionNumber10_5) {
		for (NSRunningApplication *runningApplication in [[NSWorkspace sharedWorkspace] runningApplications]) {
			NSString *runningAppBundlePath = [[[runningApplication bundleURL] path] stringByStandardizingPath];
			if ([runningAppBundlePath isEqualToString:bundlePath]) {
				return YES;
			}
		}
		return NO;
	}
#endif
	NSString *script = [NSString stringWithFormat:@"/bin/ps ax -o comm | /usr/bin/grep %@/ | /usr/bin/grep -v grep >/dev/null", ShellQuotedString(bundlePath)];
	NSTask *task = [NSTask launchedTaskWithLaunchPath:@"/bin/sh" arguments:[NSArray arrayWithObjects:@"-c", script, nil]];
	[task waitUntilExit];

	return [task terminationStatus] == 0;
}

static BOOL IsApplicationAtPathNested(NSString *path) {
	NSString *containingPath = [path stringByDeletingLastPathComponent];

	NSArray *components = [containingPath pathComponents];
	for (NSString *component in components) {
		if ([[component pathExtension] isEqualToString:@"app"]) {
			return YES;
		}
	}

	return NO;
}

static NSString *ContainingDiskImageDevice(NSString *path) {
	NSString *containingPath = [path stringByDeletingLastPathComponent];

	struct statfs fs;
	if (statfs([containingPath fileSystemRepresentation], &fs) || (fs.f_flags & MNT_ROOTFS))
		return nil;

	NSString *device = [[NSFileManager defaultManager] stringWithFileSystemRepresentation:fs.f_mntfromname length:strlen(fs.f_mntfromname)];

	NSTask *hdiutil = [[[NSTask alloc] init] autorelease];
	[hdiutil setLaunchPath:@"/usr/bin/hdiutil"];
	[hdiutil setArguments:[NSArray arrayWithObjects:@"info", @"-plist", nil]];
	[hdiutil setStandardOutput:[NSPipe pipe]];
	[hdiutil launch];
	[hdiutil waitUntilExit];

	NSData *data = [[[hdiutil standardOutput] fileHandleForReading] readDataToEndOfFile];
	NSDictionary *info = nil;
#if MAC_OS_X_VERSION_MAX_ALLOWED > MAC_OS_X_VERSION_10_5
	if (floor(NSAppKitVersionNumber) > NSAppKitVersionNumber10_5) {
		info = [NSPropertyListSerialization propertyListWithData:data options:NSPropertyListImmutable format:NULL error:NULL];
	}
	else {
#endif
#if MAC_OS_X_VERSION_MIN_REQUIRED < MAC_OS_X_VERSION_10_10
		info = [NSPropertyListSerialization propertyListFromData:data mutabilityOption:NSPropertyListImmutable format:NULL errorDescription:NULL];
#endif
#if MAC_OS_X_VERSION_MAX_ALLOWED > MAC_OS_X_VERSION_10_5
	}
#endif

	if (![info isKindOfClass:[NSDictionary class]]) return nil;

	NSArray *images = (NSArray *)[info objectForKey:@"images"];
	if (![images isKindOfClass:[NSArray class]]) return nil;

	for (NSDictionary *image in images) {
		if (![image isKindOfClass:[NSDictionary class]]) return nil;

		id systemEntities = [image objectForKey:@"system-entities"];
		if (![systemEntities isKindOfClass:[NSArray class]]) return nil;

		for (NSDictionary *systemEntity in systemEntities) {
			if (![systemEntity isKindOfClass:[NSDictionary class]]) return nil;

			NSString *devEntry = [systemEntity objectForKey:@"dev-entry"];
			if (![devEntry isKindOfClass:[NSString class]]) return nil;

			if ([devEntry isEqualToString:device])
				return device;
		}
	}

	return nil;
}

static BOOL Trash(NSString *path) {
	BOOL result = NO;
#if MAC_OS_X_VERSION_MAX_ALLOWED >= MAC_OS_X_VERSION_10_8
	if (floor(NSAppKitVersionNumber) >= NSAppKitVersionNumber10_8) {
		result = [[NSFileManager defaultManager] trashItemAtURL:[NSURL fileURLWithPath:path] resultingItemURL:NULL error:NULL];
	}
#endif
#if MAC_OS_X_VERSION_MIN_REQUIRED < MAC_OS_X_VERSION_10_11
	if (!result) {
		result = [[NSWorkspace sharedWorkspace] performFileOperation:NSWorkspaceRecycleOperation
															  source:[path stringByDeletingLastPathComponent]
														 destination:@""
															   files:[NSArray arrayWithObject:[path lastPathComponent]]
																 tag:NULL];
	}
#endif
	
	if (!result) {
		NSAppleScript *appleScript = [[[NSAppleScript alloc] initWithSource:
									   [NSString stringWithFormat:@"\
										set theFile to POSIX file \"%@\" \n\
									   	tell application \"Finder\" \n\
									  		move theFile to trash \n\
									  	end tell", path]] autorelease];
		NSDictionary *errorDict = nil;
		NSAppleEventDescriptor *scriptResult = [appleScript executeAndReturnError:&errorDict];
		if (scriptResult == nil) {
			NSLog(@"Trash AppleScript error: %@", errorDict);
		}
		result = (scriptResult != nil);
	}

	if (!result) {
		NSLog(@"ERROR -- Could not trash '%@'", path);
	}

	return result;
}

static BOOL DeleteOrTrash(NSString *path) {
	NSError *error;

	if ([[NSFileManager defaultManager] removeItemAtPath:path error:&error]) {
		return YES;
	}
	else {
		if ([path rangeOfString:@"/AppTranslocation/"].location == NSNotFound)
			NSLog(@"WARNING -- Could not delete '%@': %@", path, [error localizedDescription]);
		
		return Trash(path);
	}
}

static BOOL AuthorizedInstall(NSString *srcPath, NSString *dstPath, BOOL *canceled) {
	if (canceled) *canceled = NO;

	// Limit privileged deletion to app bundles.
	if (![[dstPath pathExtension] isEqualToString:@"app"]) return NO;

	if ([[dstPath stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]] length] == 0) return NO;
	if ([[srcPath stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]] length] == 0) return NO;

	int pid, status;
	AuthorizationRef myAuthorizationRef;

	OSStatus err = AuthorizationCreate(NULL, kAuthorizationEmptyEnvironment, kAuthorizationFlagDefaults, &myAuthorizationRef);
	if (err != errAuthorizationSuccess) return NO;

	AuthorizationItem myItems = {kAuthorizationRightExecute, 0, NULL, 0};
	AuthorizationRights myRights = {1, &myItems};
	AuthorizationFlags myFlags = (AuthorizationFlags)(kAuthorizationFlagInteractionAllowed | kAuthorizationFlagExtendRights | kAuthorizationFlagPreAuthorize);

	err = AuthorizationCopyRights(myAuthorizationRef, &myRights, NULL, myFlags, NULL);
	if (err != errAuthorizationSuccess) {
		if (err == errAuthorizationCanceled && canceled)
			*canceled = YES;
		goto fail;
	}

	static OSStatus (*security_AuthorizationExecuteWithPrivileges)(AuthorizationRef authorization, const char *pathToTool,
																   AuthorizationFlags options, char * const *arguments,
																   FILE **communicationsPipe) = NULL;
	if (!security_AuthorizationExecuteWithPrivileges) {
		// Resolve the deprecated API dynamically so unavailable systems fail cleanly.
		security_AuthorizationExecuteWithPrivileges = (OSStatus (*)(AuthorizationRef, const char*,
																   AuthorizationFlags, char* const*,
																   FILE **)) dlsym(RTLD_DEFAULT, "AuthorizationExecuteWithPrivileges");
	}
	if (!security_AuthorizationExecuteWithPrivileges) goto fail;

	{
		char *args[] = {"-rf", (char *)[dstPath fileSystemRepresentation], NULL};
		err = security_AuthorizationExecuteWithPrivileges(myAuthorizationRef, "/bin/rm", kAuthorizationFlagDefaults, args, NULL);
		if (err != errAuthorizationSuccess) goto fail;

		pid = wait(&status);
		if (pid == -1 || !WIFEXITED(status)) goto fail; // We don't care about exit status as the destination most likely does not exist
	}

	{
		char *args[] = {"-pR", (char *)[srcPath fileSystemRepresentation], (char *)[dstPath fileSystemRepresentation], NULL};
		err = security_AuthorizationExecuteWithPrivileges(myAuthorizationRef, "/bin/cp", kAuthorizationFlagDefaults, args, NULL);
		if (err != errAuthorizationSuccess) goto fail;

		pid = wait(&status);
		if (pid == -1 || !WIFEXITED(status) || WEXITSTATUS(status)) goto fail;
	}

	AuthorizationFree(myAuthorizationRef, kAuthorizationFlagDefaults);
	return YES;

fail:
	AuthorizationFree(myAuthorizationRef, kAuthorizationFlagDefaults);
	return NO;
}

static BOOL CopyBundle(NSString *srcPath, NSString *dstPath) {
	NSFileManager *fm = [NSFileManager defaultManager];
	NSError *error = nil;

	if ([fm copyItemAtPath:srcPath toPath:dstPath error:&error]) {
		return YES;
	}
	else {
		NSLog(@"ERROR -- Could not copy '%@' to '%@' (%@)", srcPath, dstPath, error);
		return NO;
	}
}

static NSString *ShellQuotedString(NSString *string) {
	return [NSString stringWithFormat:@"'%@'", [string stringByReplacingOccurrencesOfString:@"'" withString:@"'\\''"]];
}

static void Relaunch(NSString *destinationPath) {
	int pid = [[NSProcessInfo processInfo] processIdentifier];

	NSString *preOpenCmd = @"";

	NSString *quotedDestinationPath = ShellQuotedString(destinationPath);

	// Clear quarantine before relaunching to avoid a duplicate warning.
	if (floor(NSAppKitVersionNumber) > NSAppKitVersionNumber10_5) {
		preOpenCmd = [NSString stringWithFormat:@"/usr/bin/xattr -d -r com.apple.quarantine %@", quotedDestinationPath];
	}
	else {
		preOpenCmd = [NSString stringWithFormat:@"/usr/bin/xattr -d com.apple.quarantine %@", quotedDestinationPath];
	}

	NSString *script = [NSString stringWithFormat:@"(while /bin/kill -0 %d >&/dev/null; do /bin/sleep 0.1; done; %@; /usr/bin/open %@) &", pid, preOpenCmd, quotedDestinationPath];

	[NSTask launchedTaskWithLaunchPath:@"/bin/sh" arguments:[NSArray arrayWithObjects:@"-c", script, nil]];
}

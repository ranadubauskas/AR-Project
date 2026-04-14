# MagRay: Intent-Aware Selection in Dense AR Scenes
## CS 8395 (Augmented Reality) - Rana Dubauskas

## Project Goal

This project introduces MagRay, an intent-aware ray-based selection technique for dense augmented reality environments. MagRay improves upon traditional straight selection rays with a "magnetic ray" that bends towards the likely target based on user intent and scene context. The system estimates user intent using hand kinematics, local scene density, and temporal locking. The magnetic attraction toward an object is adjusted in real time, allowing users to more easily select small targets in cluttered environments. Additionally, MagRay uses a temporal confirmation lock that freeze the selection during the final confirmation gesture to limit the Heisenberg effect.  

Accurate selection of targets in dense, cluttered AR scenes is a major challenge. Previous techniques of traditional ray-casting relies on high pointing precision and fails when many targets overlap in depth or there is a small movement from hand jitter. This problem is very critical in domains such as medical training, industrial maintenance, and accessibility scenarios where selecting the correct tiny target can have significant consequences. Prior work has improved AR target aquisition through approaches like target expansion, progressive refinement, adaptive control-to-display gain, and confirmation corrections. However, these appraoches address individual sources of error in isolation. MagRay introduces a unified, intent-aware selection technique that simultaneously considers scene density, user motion, and confirmation stability by dynamically bending the selection ray toward likely target while also stabilizing selection during confirmation. By integrating these signals into a single system, MagRay improves to imprive selection accuracy in dense AR environments while preserving speed and simplicity in ray-based interactions.

## Technical Approach

MagRay will be implemented as a mobile AR selection technique on iOS using Swift, SwiftUI, ARKit, RealityKit, and Core Motion. Instead of a headset-based hand ray, the system will use a screen-space-to-world-space ray cast from the center of the iPhone screen (or a tap location) into the AR scene. 

### Core Technologies
- **ARKit (ARWorldTrackingConfiguration)**
  - Provides 6DoF tracking of the iPhone pose relative to the environment.
  - Used to continuously estimate the camera position and orientation.
- **RealityKit**
  - Handles 3D scene rendering and entity management.
  - Used to create and render **ModelEntity** spheres that represent selectable targets.
- **CoreMotion**
  - Provides processed device motion data (`CMDeviceMotion`).
  - Used to create and render **ModelEntity** spheres that represent selectable targets.
- **SwiftUI + ARView**
  - Hosts the AR interface and handles gesture input (tap confirmation).

### Scene Setup
- An **AnchorEntity** will be placed in front of the camera.
- A dense cluster of small **ModelEntity spheres** will be generated around the anchor to create a cluttered selection environment.
- Each sphere will store its world position and a temporary magnetic score used by the selection algorithm.

### Ray Generation (Screen → World)
- A ray will be generated in each frame using: `arView.ray(through: screenPoint)`
- The screen point will normally be the center of the screen, functioning as an aiming reticle.
- The ray origin and direction will be used to evaluate candidate targets.

### Magenetic Target Selection
Instead of relying on RealityKit’s built-in hit test, MagRay computes a **custom score for each target.**

For each sphere:
- Compute the **shortest distance from the ray to the sphere center**
- Convert distance into a **proximity score((
- Optionally apply a **depth weighting**
```bash
score = proximity_weight * (1 / ray_distance)
      + depth_weight * depth_bias
```
The sphere with the highest score becomes the **current candidate target**.


### Motion-Aware Assistance
Magnetic snap strength will adapt based on device movement.

Using **Core Motion:**
- Compute motion magnitude from: **rotation rate** and **user acceleration**
- Behavior:
  - Phone moving fast → weaker magnetic snap
  - Phone steady → stronger magnetic snap

This allows the system to distinguish between navigation motion and careful aiming.

### Temporal Confirmation Lock

Selection confirmation occurs with a **screen tap.**

To reduce disturbances caused by touching the phone:

- Maintain a short **rolling buffer (~80–120 ms)** of recent best targets.
- When the user taps, the system selects the most stable candidate from the recent buffer, rather than the instantaneous frame.

This reduces errors caused by device movement during the tap.

### Interaction Loop
1. ARKit updates device pose.
2. Core Motion updates device motion.
3. A world-space ray is generated from the screen center.
4. The algorithm evaluates all sphere candidates.
5. The highest-scoring target is highlighted.
6. The candidate is added to a short temporal history.
7. User taps for selection
8. The system selects the most stable candidate from the recent history.

### System Architecture
```bash
iPhone Camera + AR Session
        │
        ▼
ARKit World Tracking
        │
        ▼
Ray Generation (arView.ray)
        │
        ▼
Candidate Evaluation
(ray → sphere distance)
        │
        ▼
Magnetic Scoring
(proximity + depth)
        │
        ▼
Motion Scaling (Core Motion)
        │
        ▼
Temporal Buffer (~100 ms)
        │
        ▼
Tap Confirmation
        │
        ▼
Final Target Selection
```
### Environment Profile Summary:
- Platform: iOS Mobile Augmented Reality
- SDK / Tool: Apple ARKit + RealityKit
- SDK Version: iOS 26.2 SDK (ARKit + RealityKit included in Xcode)
- Host OS: macOS 15.6 (24G84)
- IDE: Xcode 26.2
- Target OS: iOS 26.2
- Language / UI: Swift + SwiftUI

**AR Frameworks:**
- ARKit (world tracking, camera pose estimation)
- RealityKit (scene graph, rendering, ModelEntity objects)

**Motion Framework:**
- Core Motion (CMDeviceMotion for rotation rate and user acceleration)

**Target Hardware:** 
iPhone 15 Plus

## Novelty and Contribution

MagRay is a systems integration and modification of existing AR selection techniques. 

Prior work in AR selection has explored techniques such as:
- **Target expansion** (e.g., Bubble Cursor / Bubble Ray) to enlarge effective target size
- **Progressive refinement** (e.g., Depth Ray, SQUAD) to resolve clutter through multi-step selection
- **Adaptive control-to-display gain** to improve precision during slow movement
- **Confirmation-aware methods** to correct errors caused by the click or pinch gesture

However, these techniques typically address one source of error at a time. Additionally, most are designed for headset-based VR/AR systems using hand rays or controllers.

MagRay is an integration of these ideas adapted for mobile AR. The system combines three previously separate mechanisms into a single intent-aware selection pipeline:
- **Magnetic proximity scoring** to expand the effective selection region of nearby objects
- **Motion-aware assistance** using device motion to infer whether the user is navigating or precisely aiming
- **Temporal confirmation** locking to reduce selection errors caused by the tap gesture

Aditionally, MagRay explores these ideas under a screen-space-to-world-space mobile AR interaction model, where the selection ray originates from the phone camera rather than a tracked hand.

**Contribution Summary:**
- A **mobile AR implementation** of an intent-aware magnetic selection technique
- A **unified selection pipeline** integrating proximity scoring, motion-aware assistance, and temporal confirmation stabilization
- An evaluation of whether this integration improves target selection accuracy in **dense AR** scenes

## Evaluation Plan
To evaluate whether MagRay improves target selection in dense AR scenes, I will conduct a  target acquisition experiment comparing MagRay against a baseline ray-casting technique.

### Experimental Variables

**Interaction Techniques:**
1. Baseline Ray Casting: Uses standard screen-space ray casting (object intersected by the ray is selected directly with no magnetic assistance or temporal stabilization)
2. MagRay: magnetic scoring + motion scaling + temporal lockin

**Density Conditions:**
To evaluate performance in cluttered environments, the number of targets will vary:
- **Low Density:** ~10 objects
- **Medium Density:** ~30 objects
- **High Density:** ~60 objects

Objects will be placed close together so that multiple targets lie near the ray direction.

### Setup

**10 participants** will be asked to select a highlighted target sphere among 10-20 spheres in the AR scene

**Trials:**

We will perform 12 trials per density per interaction technique. Therefore, we will have a total of 3 (densities) * 2 (interaction techiques) * 12 trials = **72 total trials**.

### Metrics
The system will automatically log:
- **Selection Accuracy:** Percentage of correct targets selected
- **Selection Time:** Time from target appearance to confirmation in ms
- **Error Rate:** Percentage of incorrect selections
- **Ray Stability:** Number of times the best candidate changes (candidate-switch count)

### Success Criteria

MagRay will be considered successful if it meets the following conditions when compared to baseline ray casting:
- **Lower error rate:** MagRay reduces incorrect selections by at least **15–20%** in medium and high density scenes.
- **Comparable or improved selection time:** Average selection time remains **within ±10% of the baseline** or becomes faster.
- **Higher accuracy in dense scenes:** In the high-density condition, MagRay achieves at least a 10% higher target selection accuracy than baseline ray casting.
- **Improved ray stability:** The average **candidate-switch count** in the 80–120 ms window before confirmation is lower than the baseline

## Milestones and Contingencies

### Minimal Viable Demo (MVD)
The minimum viable version of MagRay will include:
- An ARKit + RealityKit scene running on iPhone
- Adense cluster of selectable sphere targets
- A ray generated from the center of the screen
- A custom magnetic scoring function selecting the closest target to the ray

### Development Milestones

**Milestone 1 – AR Scene Setup**
- Initialize ARKit session using ARWorldTrackingConfiguration
- Create RealityKit scene with AnchorEntity
- Spawn dense cluster of ModelEntity spheres

**Milestone 2 – Ray Generation**
- Implement screen-space ray generation using arView.ray(through:)
- Visualize aiming reticle and highlight intersected sphere

**Milestone 3 – Magnetic Selection Algorithm**
- Compute ray-to-sphere distances
- Implement proximity-based magnetic scoring
- Highlight current best candidate

**Milestone 4 – Motion-Aware Scaling**
- Integrate Core Motion (CMDeviceMotion)
- Scale magnetic snap strength based on device movement

**Milestone 5 – Temporal Locking**
- Implement short history buffer of recent candidate targets
- Select most stable candidate at tap confirmation

**Milestone 6 – Evaluation Experiment**
- Implement experiment mode with randomized target selection
- Log selection accuracy and time
- Run evaluation trials and analyze results

### Hardest Technical Challenges
The most challenging components are likely:
- Computing **stable ray-to-object** scoring in a cluttered scene
- Preventing **rapid flickering between candidate targets**
- Balancing magnetic snap strength so it **assists but does not override user intent**

### Contingency Plan
If the full MagRay system proves too complex we will try one of the following simpler versions:
1. Implement magnetic proximity scoring only (no motion scaling).
2. Implement temporal confirmation locking only to stabilize selections.
3. Evaluate ray proximity snapping vs baseline ray casting without motion-based adaptation.

## Minimum Viable Design (MVD)

[Demo Video Link](https://vimeo.com/1178952293?share=copy&fl=sv&fe=ci)

The MVD for MagRay demonstrates that the core technical challenge of the project is feasible: an intent-aware target selection pipeline for dense mobile AR scenes running end-to-end on an iPhone. It validates that selecting a likely target in clutter using a custom ray-based scoring pipeline works in a simplified but functional form

### What is Currently Implemented

The current MVD includes a working mobile AR prototype built with **Swift, SwiftUI, ARKit, RealityKit, and Core Motion** on iPhone. The prototype supports:
- A live **ARKit world-tracked scene**
- A generated cluster of selectable **RealityKit sphere targets**
- A **screen-center selection ray** using `arView.ray(through:)`
- A **custom candidate evaluation pipeline** based on ray-to-target distance rather than RealityKit’s default hit testing
- **Baseline vs MagRay** comparison modes
- **Motion-aware magnetic assistance**, where snap strength changes based on device motion
- **Temporal confirmation stabilization / confirmation locking** to reduce errors caused by the confirmation gesture
- An **experiment mode** with randomized target selection, density conditions, and logging of trial metrics such as accuracy, selection time, and candidate-switch count

### What the MVD Demonstrates

The current prototype shows that MagRay can:
1. Generate a world-space ray from the center of the phone screen
2. Evaluate multiple nearby targets in a cluttered AR scene
3. Select a current best candidate using a custom magnetic scoring function
4. Adapt assistance strength using device motion
5. Stabilize final selection during confirmation

This is the core technical challenge of the system. The most important feasibility question for the project was whether it would be possible to replace simple ray intersection with a richer, intent-aware selection mechanism that still runs live on a mobile device. The MVD shows that this is feasible.

### What Remains to be Implemented or Improved

The main work remaining after the MVD is not the basic feasibility of MagRay, but refinement and evaluation. Remaining tasks include:
- Improving the visual presentation of the selection technique
- Tuning magnetic snap strength and temporal locking parameters
- Reducing candidate flicker in dense scenes
- Improving experiment usability and trial flow
- Collecting and analyzing evaluation data across all study conditions
- Replacing synthetic spheres with more realistic target objects if time permits

### Technical Issues Encountered
Several issues emerged during implementation:

- Ray on screen was blocking visibility of scene --> had to make thinner
- Candidate flickering between nearby targets in dense scenes
- Balancing snap strength so that MagRay assists the user without feeling overly “sticky,”
### Technical Issues Encountered
- AR performance and world-tracking stability under heavier scene (`ARWorldTrackingTechnique ... World tracking performance is being affected by resource constraints [33 ]`)
- Designing a visualization that communicates “magnetic” behavior clearly without misleading the user

### Scope Changes

The original proposal framed MagRay partly as a “magnetic ray” that bends toward likely targets. During development, the project evolved toward a more concrete and technically robust interpretation: a straight screen-center ray combined with intent-aware target scoring, motion scaling, and confirmation stabilization. This is still consistent with the project’s novelty claims, but it shifts the emphasis from visual ray deformation to the underlying selection pipeline itself. The novelty claim is therefore now more accurately centered on the unified intent-aware selection system rather than on a literal geometric ray-bending visualization.

### Contingency & Risk Assessment

The highest remaining technical risk is no longer whether MagRay can be implemented, but whether the final system will show a strong enough improvement over baseline in dense scenes while still feeling natural to use. The main remaining risks are:
- The possibility that magnetic assistance may help accuracy but slow down selection
- The possibility that confirmation locking may feel overly sticky if not tuned carefully
- The challenge of making the system’s benefit obvious in user evaluation

If needed, the contingency path is to simplify the final system and evaluate the strongest subset of the technique, such as:
1. Magnetic proximity scoring + baseline comparison only
2. Temporal confirmation stabilization + baseline comparison only
3. Magnetic scoring + temporal stabilization without motion-aware scaling

## Final Report

### Experimental Design
*Raw experimental data can be found in [experiment_results.json](https://github.com/ranadubauskas/AR-Project/blob/main/experiment_results.json)*

The evaluation used a repeated-measures AR target selection experiment comparing Baseline Ray Casting and MagRay. The study included 10 participants, all of whom were Vanderbilt University college students. Each participant completed a run of 72 randomized trials across three density conditions: Low, Medium, and High. In total, the dataset consisted of 720 trials, evenly split between Baseline and MagRay and evenly distributed across density conditions. Trial order was randomized to reduce immediate memory and carryover effects, while matched layoutSeed and targetIndex pairs ensured that the two techniques were evaluated on the same underlying scene layouts and target selections.

### Results
### Table 1. Dataset Overview

| Measure | Value |
|---|---:|
| Experiments | 10 |
| Trials total | 720 |
| Trials per experiment | 72 |
| Baseline trials total | 360 |
| MagRay trials total | 360 |
| Low trials total | 240 |
| Medium trials total | 240 |
| High trials total | 240 |

#### Analysis
- Balanced design: equal Baseline vs. MagRay trial counts and equal Low, Medium, and High density trial counts.
- Large enough dataset to compare methods fairly across density conditions.

---

### Table 2. Performance by Mode

| Metric | Baseline Ray Casting | MagRay | Absolute Improvement | Relative Change |
|---|---:|---:|---:|---:|
| Overall Selection Accuracy | 90.3% | 87.8% | -2.5% | 2.8% worse |
| Overall Error Rate | 9.7% | 12.2% | +2.5% | 25.7% higher |
| Average Selection Time (ms) | 1450.0 ms | 1387.1 ms | -62.9 ms | 4.3% faster |
| Median Selection Time | 1330.2 ms | 1269.6 ms | -60.6 ms | 4.56% faster |
| Average Ray Stability (Switches) | 7.74 | 7.33 | -0.41 | 5.2% more stable |

#### Analysis
- Baseline was more accurate overall; MagRay had a higher overall error rate.
- MagRay was slightly faster and slightly more stable overall.
- Implication: MagRay improves speed and smoothness, but not overall correctness yet.

---

### Table 3. Performance by Density & Mode

| Density | Mode | Trials | Accuracy | Error Rate | Mean Time (ms) | Median Time (ms) | Mean Switches |
|---|---|---:|---:|---:|---:|---:|---:|
| High | Baseline | 120 | 86.7% | 13.3% | 1546.4 | 1413.0 | 9.12 |
| High | MagRay | 120 | 81.7% | 18.3% | 1409.7 | 1303.9 | 8.57 |
| Low | Baseline | 120 | 96.7% | 3.3% | 1373.3 | 1297.0 | 6.16 |
| Low | MagRay | 120 | 91.7% | 8.3% | 1363.0 | 1244.9 | 5.92 |
| Medium | Baseline | 120 | 87.5% | 12.5% | 1430.4 | 1334.6 | 7.92 |
| Medium | MagRay | 120 | 90.0% | 10.0% | 1388.7 | 1292.8 | 7.50 |

#### Analysis
- Low density: Baseline was better; MagRay adds little benefit when the task is already easy.
- Medium density: MagRay performed best, with better accuracy, speed, and stability.
- High density: MagRay was faster, but accuracy dropped too much.

---

### Table 4. Density-Specific MagRay vs. Baseline

| Density | Metric | Baseline | MagRay | Difference (MagRay - Baseline) | Interpretation |
|---|---|---:|---:|---:|---|
| High | Accuracy | 86.7% | 81.7% | -5.0 percentage points | MagRay was less accurate in high-density scenes |
| High | Mean Selection Time | 1546.4 ms | 1409.7 ms | -136.7 ms | MagRay was faster in high-density scenes |
| High | Mean Candidate Switches | 9.12 | 8.57 | -0.55 | MagRay was slightly more stable in high-density scenes |
| Low | Accuracy | 96.7% | 91.7% | -5.0 percentage points | MagRay was less accurate in low-density scenes |
| Low | Mean Selection Time | 1373.3 ms | 1363.0 ms | -10.3 ms | The speed difference was very small in low-density scenes |
| Low | Mean Candidate Switches | 6.16 | 5.92 | -0.24 | MagRay was only slightly more stable in low-density scenes |
| Medium | Accuracy | 87.5% | 90.0% | +2.5 percentage points | MagRay was more accurate in medium-density scenes |
| Medium | Mean Selection Time | 1430.4 ms | 1388.7 ms | -41.7 ms | MagRay was faster in medium-density scenes |
| Medium | Mean Candidate Switches | 7.92 | 7.50 | -0.42 | MagRay was slightly more stable in medium-density scenes |

#### Analysis
- MagRay was faster and a bit more stable at every density.
- Accuracy only improved in Medium density; it got worse in Low and High.
- Main implication: MagRay helps most in moderate clutter, not very easy or very hard scenes.

---

### Table 5. Per-Experiment Summary by Mode

| Experiment | Mode | Trials | Accuracy | Mean Time (ms) | Median Time (ms) | Mean Switches |
|---:|---|---:|---:|---:|---:|---:|
| 1 | Baseline | 36 | 91.7 | 1467.2 | 1376.0 | 7.47 |
| 1 | MagRay | 36 | 88.9 | 1529.8 | 1452.1 | 6.94 |
| 2 | Baseline | 36 | 88.9 | 1590.8 | 1289.9 | 8.67 |
| 2 | MagRay | 36 | 91.7 | 1265.5 | 1169.0 | 7.64 |
| 3 | Baseline | 36 | 86.1 | 1504.7 | 1325.1 | 8.08 |
| 3 | MagRay | 36 | 88.9 | 1351.8 | 1259.9 | 7.94 |
| 4 | Baseline | 36 | 88.9 | 1397.7 | 1305.5 | 7.22 |
| 4 | MagRay | 36 | 88.9 | 1466.7 | 1364.6 | 7.72 |
| 5 | Baseline | 36 | 94.4 | 1385.1 | 1326.9 | 7.58 |
| 5 | MagRay | 36 | 91.7 | 1687.5 | 1336.1 | 8.11 |
| 6 | Baseline | 36 | 88.9 | 1596.8 | 1379.8 | 7.72 |
| 6 | MagRay | 36 | 86.1 | 1275.1 | 1236.4 | 6.83 |
| 7 | Baseline | 36 | 88.9 | 1459.1 | 1299.6 | 8.11 |
| 7 | MagRay | 36 | 88.9 | 1386.1 | 1199.4 | 7.08 |
| 8 | Baseline | 36 | 97.2 | 1452.5 | 1366.2 | 7.58 |
| 8 | MagRay | 36 | 77.8 | 1409.5 | 1276.2 | 7.81 |
| 9 | Baseline | 36 | 94.4 | 1331.3 | 1310.0 | 7.25 |
| 9 | MagRay | 36 | 80.6 | 1296.0 | 1245.4 | 6.69 |
| 10 | Baseline | 36 | 83.3 | 1314.8 | 1207.4 | 7.67 |
| 10 | MagRay | 36 | 94.4 | 1203.5 | 1184.4 | 6.53 |

#### Analysis
- Results vary a lot across runs: some experiments favor MagRay, others favor Baseline.
- MagRay’s speed and stability gains are more consistent than its accuracy gains.
- This suggests layout-specific effects or fragile tuning are still influencing outcomes.

---

### Table 6. Comparison for Matched Layouts (Same Scene/Target)

| Density | Matched Pairs | MagRay better accuracy | Baseline better accuracy | Accuracy tie | MagRay faster | Baseline faster | MagRay fewer switches | Baseline fewer switches |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| High | 120 | 11 | 17 | 92 | 66 | 54 | 55 | 45 |
| Low | 120 | 3 | 9 | 108 | 73 | 47 | 53 | 47 |
| Medium | 120 | 14 | 11 | 95 | 59 | 61 | 61 | 42 |

#### Analysis
- This is the fairest comparison because both methods see the same exact scene/target pair.
- Medium density favors MagRay more often; High density favors Baseline more often.
- Low density is mostly ties, meaning assistance is not very necessary there.

---

### Table 7. Failures by Density & Mode

| Density | Mode | Failures | Error Rate | Mean Error Time (ms) |
|---|---|---:|---:|---:|
| High | Baseline | 16 | 13.3% | 1891.4 |
| High | MagRay | 22 | 18.3% | 1475.1 |
| Low | Baseline | 4 | 3.3% | 1438.3 |
| Low | MagRay | 10 | 8.3% | 1216.5 |
| Medium | Baseline | 15 | 12.5% | 1282.0 |
| Medium | MagRay | 12 | 10.0% | 1336.8 |

#### Analysis
- MagRay had fewer failures only in Medium density.
- In Low and High density, MagRay produced more errors than Baseline.
- MagRay’s errors also tended to happen faster, suggesting quick wrong snaps rather than slow searching.

---

### Overall Analysis
- Strongest result: MagRay looks most promising in Medium density.
- Biggest weakness: High-density accuracy is still not reliable enough.
- Best next step: fix bad layouts and retune High-density behavior while preserving the Medium-density benefit.


